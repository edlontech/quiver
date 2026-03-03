defmodule Quiver.Pool.HTTP2 do
  @moduledoc """
  HTTP/2 connection pool coordinator.

  A gen_state_machine per origin that routes concurrent callers to available
  stream slots across one or more HTTP/2 connection workers. Opens new connections
  when all existing ones are at max_concurrent_streams. Queues callers when the
  connection count is also at the maximum.

  The coordinator uses a two-phase caller model:
  1. Caller sends a gen_statem call to the coordinator (checkout phase).
  2. Coordinator forwards the request to a connection worker via message.
  3. The connection worker replies directly to the caller's `from` reference.
  """

  use GenStateMachine, callback_mode: [:state_functions, :state_enter]

  alias Quiver.Error.CheckoutTimeout
  alias Quiver.Error.StreamError
  alias Quiver.Pool.HTTP2.Connection
  alias Quiver.StreamResponse

  @behaviour Quiver.Pool

  defstruct [
    :origin,
    :config,
    connections: %{},
    waiting: :queue.new(),
    max_connections: 5,
    checkout_timeout: 15_000
  ]

  @type t :: %__MODULE__{
          origin: term(),
          config: map() | nil,
          connections: map(),
          waiting: :queue.queue(),
          max_connections: pos_integer(),
          checkout_timeout: pos_integer()
        }

  @doc false
  def child_spec(opts) do
    origin = Keyword.fetch!(opts, :origin)

    %{
      id: {__MODULE__, origin},
      start: {__MODULE__, :start_link, [opts]},
      type: :worker
    }
  end

  @doc "Starts the HTTP/2 pool coordinator."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)
    args = if name, do: [name: name], else: []
    GenStateMachine.start_link(__MODULE__, opts, args)
  end

  @impl Quiver.Pool
  @spec request(pid(), atom(), String.t(), list(), iodata() | nil, keyword()) ::
          {:ok, Quiver.Response.t()} | {:error, term()}
  def request(pool, method, path, headers, body, opts \\ []) do
    timeout = Keyword.get(opts, :recv_timeout, 15_000)
    checkout_timeout = Keyword.get(opts, :checkout_timeout, timeout)
    do_request(pool, method, path, headers, body, opts, checkout_timeout)
  end

  defp do_request(pool, method, path, headers, body, opts, checkout_timeout) do
    GenStateMachine.call(pool, {:request, method, path, headers, body, opts}, checkout_timeout)
  catch
    :exit, {:timeout, _} ->
      {:error, CheckoutTimeout.exception(origin: "unknown", timeout: checkout_timeout)}
  end

  @impl Quiver.Pool
  @spec stream_request(pid(), atom(), String.t(), list(), iodata() | nil, keyword()) ::
          {:ok, StreamResponse.t()} | {:error, term()}
  def stream_request(pool, method, path, headers, body, opts \\ []) do
    timeout = Keyword.get(opts, :recv_timeout, 15_000)
    checkout_timeout = Keyword.get(opts, :checkout_timeout, timeout)

    case do_stream_request(pool, method, path, headers, body, opts, checkout_timeout) do
      {:ok, status, resp_headers, ref, worker_pid} ->
        {:ok,
         %StreamResponse{
           status: status,
           headers: resp_headers,
           body: build_h2_body_stream(ref, worker_pid),
           ref: ref
         }}

      {:error, _} = error ->
        error
    end
  end

  defp do_stream_request(pool, method, path, headers, body, opts, checkout_timeout) do
    GenStateMachine.call(
      pool,
      {:stream_request, method, path, headers, body, opts},
      checkout_timeout
    )
  catch
    :exit, {:timeout, _} ->
      {:error, CheckoutTimeout.exception(origin: "unknown", timeout: checkout_timeout)}
  end

  defp build_h2_body_stream(ref, worker_pid) do
    Stream.resource(
      fn -> {ref, worker_pid} end,
      fn {ref, worker_pid} ->
        send(worker_pid, {:demand, ref, self()})

        receive do
          {:chunk, ^ref, data} -> {[data], {ref, worker_pid}}
          {:done, ^ref} -> {:halt, {ref, worker_pid}}
          {:error, ^ref, reason} -> raise StreamError.exception(reason: reason)
        end
      end,
      fn {ref, worker_pid} ->
        send(worker_pid, {:cancel_stream, ref, self()})
      end
    )
  end

  @impl Quiver.Pool
  @spec stats(pid()) :: %{
          idle: non_neg_integer(),
          active: non_neg_integer(),
          queued: non_neg_integer(),
          connections: non_neg_integer()
        }
  def stats(pool) do
    GenStateMachine.call(pool, :stats)
  catch
    :exit, _ -> %{active: 0, idle: 0, queued: 0, connections: 0}
  end

  @impl true
  def init(opts) do
    origin = Keyword.fetch!(opts, :origin)
    config = Keyword.get(opts, :pool_opts, [])

    :persistent_term.put({__MODULE__, self()}, true)

    data = %__MODULE__{
      origin: origin,
      config: config,
      max_connections: Keyword.get(config, :max_connections, 5),
      checkout_timeout: Keyword.get(config, :checkout_timeout, 15_000)
    }

    {:ok, :idle, data}
  end

  @impl true
  def terminate(_reason, _state, _data) do
    :persistent_term.erase({__MODULE__, self()})
    :ok
  end

  # -- :idle state (no connections yet) --

  def idle(:enter, _old, data) do
    {:keep_state, sweep_expired(data)}
  end

  def idle({:call, from}, {:request, method, path, headers, body, opts}, data) do
    case start_connection(data) do
      {:ok, conn_pid, data} ->
        forward_request(conn_pid, from, method, path, headers, body, opts)
        {:next_state, :connected, data}

      {:error, reason, data} ->
        {:keep_state, data, [{:reply, from, {:error, reason}}]}
    end
  end

  def idle({:call, from}, {:stream_request, method, path, headers, body, opts}, data) do
    case start_connection(data) do
      {:ok, conn_pid, data} ->
        forward_stream(conn_pid, from, method, path, headers, body, opts)
        {:next_state, :connected, data}

      {:error, reason, data} ->
        {:keep_state, data, [{:reply, from, {:error, reason}}]}
    end
  end

  def idle({:call, from}, :stats, data) do
    {:keep_state_and_data, [{:reply, from, read_stats(data)}]}
  end

  def idle(:info, :sweep_queue, data) do
    {:keep_state, sweep_expired(data)}
  end

  def idle(:info, {:DOWN, _ref, :process, _conn_pid, _reason}, _data) do
    :keep_state_and_data
  end

  # -- :connected state (at least one connection available) --

  def connected(:enter, _old, _data), do: :keep_state_and_data

  def connected({:call, from}, {:request, method, path, headers, body, opts}, data) do
    case pick_connection(data) do
      {:ok, conn_pid} ->
        forward_request(conn_pid, from, method, path, headers, body, opts)
        {:keep_state, data}

      :none_available ->
        handle_none_available(from, method, path, headers, body, opts, data)
    end
  end

  def connected({:call, from}, {:stream_request, method, path, headers, body, opts}, data) do
    case pick_connection(data) do
      {:ok, conn_pid} ->
        forward_stream(conn_pid, from, method, path, headers, body, opts)
        {:keep_state, data}

      :none_available ->
        handle_none_available_stream(from, method, path, headers, body, opts, data)
    end
  end

  def connected({:call, from}, :stats, data) do
    {:keep_state_and_data, [{:reply, from, read_stats(data)}]}
  end

  def connected(:info, {:stream_done, conn_pid}, data) do
    data = update_connection_stream_count(data, conn_pid, -1)
    data = maybe_dequeue(data)
    {:keep_state, data}
  end

  def connected(:info, {:stream_opened, conn_pid}, data) do
    data = update_connection_stream_count(data, conn_pid, 1)
    {:keep_state, data}
  end

  def connected(:info, {:connection_draining, conn_pid}, data) do
    case data.connections do
      %{^conn_pid => _} ->
        {:keep_state, put_in(data.connections[conn_pid].state, :draining)}

      _ ->
        :keep_state_and_data
    end
  end

  def connected(:info, {:DOWN, _ref, :process, conn_pid, _reason}, data) do
    {_conn_info, connections} = Map.pop(data.connections, conn_pid)
    data = %{data | connections: connections}

    if map_size(connections) == 0 do
      {:next_state, :idle, data}
    else
      {:keep_state, data}
    end
  end

  def connected(:info, :sweep_queue, data) do
    {:keep_state, sweep_expired(data)}
  end

  # -- Private helpers --

  defp handle_none_available(from, method, path, headers, body, opts, data) do
    if map_size(data.connections) < data.max_connections do
      case start_connection(data) do
        {:ok, conn_pid, data} ->
          forward_request(conn_pid, from, method, path, headers, body, opts)
          {:keep_state, data}

        {:error, _reason, data} ->
          enqueue(from, method, path, headers, body, opts, data)
      end
    else
      enqueue(from, method, path, headers, body, opts, data)
    end
  end

  defp start_connection(data) do
    opts = [
      origin: data.origin,
      config: data.config,
      pool_pid: self()
    ]

    case Connection.start_link(opts) do
      {:ok, pid} ->
        ref = Process.monitor(pid)
        max = Connection.max_streams(pid)
        conn_info = %{ref: ref, stream_count: 0, max_streams: max, state: :connected}
        connections = Map.put(data.connections, pid, conn_info)
        {:ok, pid, %{data | connections: connections}}

      {:error, reason} ->
        {:error, reason, data}
    end
  end

  defp pick_connection(data) do
    result =
      data.connections
      |> Enum.filter(fn {_pid, info} ->
        info.state == :connected and info.stream_count < info.max_streams
      end)
      |> Enum.min_by(fn {_pid, info} -> info.stream_count end, fn -> nil end)

    case result do
      {pid, _info} -> {:ok, pid}
      nil -> :none_available
    end
  end

  defp handle_none_available_stream(from, method, path, headers, body, opts, data) do
    if map_size(data.connections) < data.max_connections do
      case start_connection(data) do
        {:ok, conn_pid, data} ->
          forward_stream(conn_pid, from, method, path, headers, body, opts)
          {:keep_state, data}

        {:error, _reason, data} ->
          enqueue_stream(from, method, path, headers, body, opts, data)
      end
    else
      enqueue_stream(from, method, path, headers, body, opts, data)
    end
  end

  defp forward_request(conn_pid, from, method, path, headers, body, opts) do
    timeout = Keyword.get(opts, :recv_timeout, 15_000)
    send(conn_pid, {:forward_request, from, method, path, headers, body, timeout})
  end

  defp forward_stream(conn_pid, from, method, path, headers, body, opts) do
    timeout = Keyword.get(opts, :recv_timeout, 15_000)
    send(conn_pid, {:forward_stream, from, method, path, headers, body, timeout})
  end

  defp enqueue(from, method, path, headers, body, opts, data) do
    deadline = System.monotonic_time(:millisecond) + data.checkout_timeout
    entry = {from, method, path, headers, body, opts, deadline}
    data = %{data | waiting: :queue.in(entry, data.waiting)}
    schedule_sweep()
    {:keep_state, data}
  end

  defp enqueue_stream(from, method, path, headers, body, opts, data) do
    deadline = System.monotonic_time(:millisecond) + data.checkout_timeout
    entry = {:stream, from, method, path, headers, body, opts, deadline}
    data = %{data | waiting: :queue.in(entry, data.waiting)}
    schedule_sweep()
    {:keep_state, data}
  end

  defp maybe_dequeue(data) do
    case :queue.out(data.waiting) do
      {:empty, _} -> data
      {{:value, entry}, rest} -> dequeue_entry(entry, rest, data)
    end
  end

  defp dequeue_entry(entry, rest, data) do
    {from, deadline} = entry_from_and_deadline(entry)

    if System.monotonic_time(:millisecond) >= deadline do
      reply_timeout(from, data)
      maybe_dequeue(%{data | waiting: rest})
    else
      dispatch_queued(entry, rest, data)
    end
  end

  defp entry_from_and_deadline({from, _, _, _, _, _, deadline}), do: {from, deadline}
  defp entry_from_and_deadline({:stream, from, _, _, _, _, _, deadline}), do: {from, deadline}

  defp reply_timeout(from, data) do
    origin_str = format_origin(data.origin)

    GenStateMachine.reply(
      from,
      {:error, CheckoutTimeout.exception(origin: origin_str, timeout: data.checkout_timeout)}
    )
  end

  defp dispatch_queued({from, method, path, headers, body, opts, _deadline}, rest, data) do
    case pick_connection(data) do
      {:ok, conn_pid} ->
        forward_request(conn_pid, from, method, path, headers, body, opts)
        %{data | waiting: rest}

      :none_available ->
        data
    end
  end

  defp dispatch_queued({:stream, from, method, path, headers, body, opts, _deadline}, rest, data) do
    case pick_connection(data) do
      {:ok, conn_pid} ->
        forward_stream(conn_pid, from, method, path, headers, body, opts)
        %{data | waiting: rest}

      :none_available ->
        data
    end
  end

  defp sweep_expired(data) do
    now = System.monotonic_time(:millisecond)
    origin_str = format_origin(data.origin)

    {expired, remaining} =
      data.waiting
      |> :queue.to_list()
      |> Enum.split_with(fn entry ->
        {_from, deadline} = entry_from_and_deadline(entry)
        now >= deadline
      end)

    Enum.each(expired, fn entry ->
      {from, _deadline} = entry_from_and_deadline(entry)

      GenStateMachine.reply(
        from,
        {:error, CheckoutTimeout.exception(origin: origin_str, timeout: data.checkout_timeout)}
      )
    end)

    %{data | waiting: :queue.from_list(remaining)}
  end

  defp schedule_sweep do
    Process.send_after(self(), :sweep_queue, 1_000)
  end

  defp update_connection_stream_count(data, conn_pid, delta) do
    case data.connections do
      %{^conn_pid => conn_info} ->
        put_in(data.connections[conn_pid].stream_count, conn_info.stream_count + delta)

      _ ->
        data
    end
  end

  defp read_stats(data) do
    active = Enum.sum(for {_, info} <- data.connections, do: info.stream_count)

    idle =
      Enum.sum(
        for {_, info} <- data.connections,
            info.state == :connected,
            do: info.max_streams - info.stream_count
      )

    queued = :queue.len(data.waiting)

    %{active: active, idle: idle, queued: queued, connections: map_size(data.connections)}
  end

  defp format_origin({scheme, host, port}), do: "#{scheme}://#{host}:#{port}"
end
