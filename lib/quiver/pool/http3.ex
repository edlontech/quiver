defmodule Quiver.Pool.HTTP3 do
  @moduledoc """
  HTTP/3 pool coordinator.

  A gen_state_machine per origin that routes concurrent callers to available
  stream slots across one or more `Pool.HTTP3.Connection` workers. Mirrors
  `Pool.HTTP2`: eagerly opens new connections until `max_connections` is reached,
  least-loaded picks across connections with available stream capacity, and
  queues callers when all slots are saturated.

  States: `:idle` -> `:connected`. The coordinator self-registers in
  `:persistent_term` so that `Pool.Manager` can detect the protocol from a
  bare pid. Uses the two-phase caller model: the caller issues a gen_statem
  call to the coordinator, the coordinator forwards `{:forward_request, from, ...}`
  to the connection worker, and the worker replies directly to the caller's
  `from`.

  HTTP/3 handshake is asynchronous (`:connecting` -> `:connected` inside the
  worker), so a freshly started connection cannot accept requests yet. The
  worker notifies the coordinator with `{:connection_ready, pid, max_streams}`
  on entering `:connected`, at which point the coordinator flips the per-
  connection entry from `:connecting` to `:connected` and starts picking it.
  """

  use GenStateMachine, callback_mode: [:state_functions, :state_enter]

  alias Quiver.Error.CheckoutTimeout
  alias Quiver.Error.StreamError
  alias Quiver.Pool.HTTP3.Connection
  alias Quiver.Pool.HTTP3.EarlyData
  alias Quiver.Pool.HTTP3.SessionTicket
  alias Quiver.Pool.Registration
  alias Quiver.StreamResponse

  @behaviour Quiver.Pool

  @max_tickets 5

  defstruct [
    :origin,
    :config,
    :conn_sup,
    connections: %{},
    waiting: :queue.new(),
    max_connections: 1,
    checkout_timeout: 5_000,
    tickets: [],
    early_connecting: nil
  ]

  @type t :: %__MODULE__{
          origin: term(),
          config: keyword(),
          conn_sup: pid() | nil,
          connections: map(),
          waiting: :queue.queue(),
          max_connections: pos_integer(),
          checkout_timeout: pos_integer(),
          tickets: [{term(), integer()}],
          early_connecting: pid() | nil
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

  @doc "Starts the HTTP/3 pool coordinator."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenStateMachine.start_link(__MODULE__, opts, [])
  end

  @impl Quiver.Pool
  @spec request(pid(), atom(), String.t(), list(), iodata() | nil, keyword()) ::
          {:ok, Quiver.Response.t()} | {:error, term()}
  def request(pool, method, path, headers, body, opts \\ []) do
    timeout = Keyword.get(opts, :receive_timeout, 15_000)
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
    timeout = Keyword.get(opts, :receive_timeout, 15_000)
    checkout_timeout = Keyword.get(opts, :checkout_timeout, timeout)

    case do_stream_request(pool, method, path, headers, body, opts, checkout_timeout) do
      {:ok, status, resp_headers, ref, worker_pid} ->
        {:ok,
         %StreamResponse{
           status: status,
           headers: resp_headers,
           body: build_h3_body_stream(ref, worker_pid),
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

  defp build_h3_body_stream(ref, worker_pid) do
    Stream.resource(
      fn -> {ref, worker_pid} end,
      fn {ref, worker_pid} ->
        send(worker_pid, {:demand, ref, self()})

        receive do
          {:chunk, ^ref, data} -> {[data], {ref, worker_pid}}
          {:trailers, ^ref, _trailers} -> {[], {ref, worker_pid}}
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

  @doc false
  @spec first_worker(pid()) :: pid() | nil
  def first_worker(pool) do
    GenStateMachine.call(pool, :first_worker)
  end

  @doc """
  Opens a datagram channel through this pool. Internal entry point used by
  `Quiver.HTTP3.open_datagram_channel/4`.

  Forwards `{:forward_open_channel, from, method, path, headers, channel_opts}`
  to a picked worker, mirroring the `:forward_request` two-phase model. The
  worker replies directly to `from` with `{:ok, %Channel{}, ref}` or
  `{:error, term}`.
  """
  @spec open_channel(pid(), atom(), String.t(), list(), keyword(), keyword()) ::
          {:ok, Quiver.HTTP3.Channel.t(), reference()} | {:error, term()}
  def open_channel(pool, method, path, headers, channel_opts, opts \\ []) do
    timeout = Keyword.get(opts, :open_timeout, 5_000)
    do_open_channel(pool, method, path, headers, channel_opts, timeout)
  end

  defp do_open_channel(pool, method, path, headers, channel_opts, timeout) do
    GenStateMachine.call(
      pool,
      {:open_channel, method, path, headers, channel_opts},
      timeout
    )
  catch
    :exit, {:timeout, _} ->
      {:error, CheckoutTimeout.exception(origin: "unknown", timeout: timeout)}
  end

  @impl true
  def init(opts) do
    origin = Keyword.fetch!(opts, :origin)
    config = Keyword.get(opts, :pool_opts, [])
    name = Keyword.get(opts, :name)

    :persistent_term.put({__MODULE__, self()}, true)

    case Registration.register(self(), name) do
      :ok ->
        {:ok, conn_sup} = DynamicSupervisor.start_link(strategy: :one_for_one)

        data = %__MODULE__{
          origin: origin,
          config: config,
          conn_sup: conn_sup,
          max_connections: Keyword.get(config, :max_connections, 1),
          checkout_timeout: Keyword.get(config, :checkout_timeout, 5_000)
        }

        {:ok, :idle, data}

      {:error, {:already_started, _existing}} = err ->
        :persistent_term.erase({__MODULE__, self()})
        {:stop, elem(err, 1)}
    end
  end

  @impl true
  def terminate(_reason, _state, _data) do
    :persistent_term.erase({__MODULE__, self()})
    :ok
  end

  # -- :idle state --

  def idle(:enter, _old, data) do
    {:keep_state, sweep_expired(data)}
  end

  def idle({:call, from}, {:request, method, path, headers, body, opts}, data) do
    case start_connection(data) do
      {:ok, _conn_pid, data} ->
        data = route_first_request(from, method, path, headers, body, opts, data)
        {:next_state, :connected, data}

      {:error, reason, data} ->
        {:keep_state, data, [{:reply, from, {:error, reason}}]}
    end
  end

  def idle({:call, from}, {:stream_request, method, path, headers, body, opts}, data) do
    case start_connection(data) do
      {:ok, _conn_pid, data} ->
        data = enqueue(from, :streaming, method, path, headers, body, opts, data)
        {:next_state, :connected, data}

      {:error, reason, data} ->
        {:keep_state, data, [{:reply, from, {:error, reason}}]}
    end
  end

  def idle({:call, from}, {:open_channel, method, path, headers, channel_opts}, data) do
    case start_connection(data) do
      {:ok, _conn_pid, data} ->
        data = enqueue_channel(from, method, path, headers, channel_opts, data)
        {:next_state, :connected, data}

      {:error, reason, data} ->
        {:keep_state, data, [{:reply, from, {:error, reason}}]}
    end
  end

  def idle({:call, from}, :stats, data) do
    {:keep_state_and_data, [{:reply, from, read_stats(data)}]}
  end

  def idle({:call, from}, :first_worker, data) do
    {:keep_state_and_data, [{:reply, from, lookup_first_worker(data)}]}
  end

  def idle(:info, :sweep_queue, data) do
    {:keep_state, sweep_expired(data)}
  end

  def idle(:info, {:session_ticket, _origin, ticket}, data) do
    {:keep_state, cache_ticket(data, ticket)}
  end

  def idle(:info, {:connection_ready, conn_pid, max}, data) do
    data = mark_connected(data, conn_pid, max)
    data = clear_early_connecting(data, conn_pid)
    data = dispatch_all_ready(data)
    {:keep_state, data}
  end

  def idle(:info, {:stream_done, conn_pid}, data) do
    {:keep_state, update_connection_stream_count(data, conn_pid, -1)}
  end

  def idle(:info, {:stream_open_failed, conn_pid}, data) do
    {:keep_state, update_connection_stream_count(data, conn_pid, -1)}
  end

  def idle(:info, {:connection_draining, conn_pid}, data) do
    {:keep_state, mark_draining(data, conn_pid)}
  end

  def idle(:info, {:DOWN, _ref, :process, conn_pid, _reason}, data) do
    connections = Map.delete(data.connections, conn_pid)
    data = clear_early_connecting(data, conn_pid)
    {:keep_state, %{data | connections: connections}}
  end

  # -- :connected state --

  def connected(:enter, _old, _data), do: :keep_state_and_data

  def connected({:call, from}, {:request, method, path, headers, body, opts}, data) do
    if data.early_connecting && EarlyData.eligible?(method, opts, data.config) do
      data =
        forward_early_request(
          data.early_connecting,
          from,
          method,
          path,
          headers,
          body,
          opts,
          data
        )

      {:keep_state, data}
    else
      route_request_normally(from, method, path, headers, body, opts, data)
    end
  end

  def connected({:call, from}, {:stream_request, method, path, headers, body, opts}, data) do
    case maybe_expand_and_pick(data) do
      {:ok, conn_pid, data} ->
        data = forward_stream(conn_pid, from, method, path, headers, body, opts, data)
        {:keep_state, data}

      {:pending, data} ->
        data = enqueue(from, :streaming, method, path, headers, body, opts, data)
        {:keep_state, data}

      :none_available ->
        data = enqueue(from, :streaming, method, path, headers, body, opts, data)
        {:keep_state, data}
    end
  end

  def connected({:call, from}, {:open_channel, method, path, headers, channel_opts}, data) do
    case maybe_expand_and_pick(data) do
      {:ok, conn_pid, data} ->
        data = forward_open_channel(conn_pid, from, method, path, headers, channel_opts, data)
        {:keep_state, data}

      {:pending, data} ->
        data = enqueue_channel(from, method, path, headers, channel_opts, data)
        {:keep_state, data}

      :none_available ->
        data = enqueue_channel(from, method, path, headers, channel_opts, data)
        {:keep_state, data}
    end
  end

  def connected({:call, from}, :stats, data) do
    {:keep_state_and_data, [{:reply, from, read_stats(data)}]}
  end

  def connected({:call, from}, :first_worker, data) do
    {:keep_state_and_data, [{:reply, from, lookup_first_worker(data)}]}
  end

  def connected(:info, {:connection_ready, conn_pid, max}, data) do
    data = mark_connected(data, conn_pid, max)
    data = clear_early_connecting(data, conn_pid)
    data = dispatch_all_ready(data)
    {:keep_state, data}
  end

  def connected(:info, {:stream_done, conn_pid}, data) do
    data = update_connection_stream_count(data, conn_pid, -1)
    data = maybe_dequeue(data)
    {:keep_state, data}
  end

  def connected(:info, {:stream_open_failed, conn_pid}, data) do
    data = update_connection_stream_count(data, conn_pid, -1)
    data = maybe_dequeue(data)
    {:keep_state, data}
  end

  def connected(:info, :sweep_queue, data) do
    {:keep_state, sweep_expired(data)}
  end

  def connected(:info, {:session_ticket, _origin, ticket}, data) do
    {:keep_state, cache_ticket(data, ticket)}
  end

  def connected(:info, {:connection_draining, conn_pid}, data) do
    {:keep_state, mark_draining(data, conn_pid)}
  end

  def connected(:info, {:DOWN, _ref, :process, conn_pid, _reason}, data) do
    connections = Map.delete(data.connections, conn_pid)
    data = clear_early_connecting(data, conn_pid)
    data = %{data | connections: connections}

    if map_size(connections) == 0 do
      {:next_state, :idle, data}
    else
      {:keep_state, dispatch_all_ready(data)}
    end
  end

  # -- helpers --

  defp cache_ticket(data, ticket) do
    now = System.system_time(:second)
    tickets = Enum.take([{ticket, now} | data.tickets], @max_tickets)
    %{data | tickets: tickets}
  end

  defp pop_ticket(%{tickets: tickets} = data) do
    now = System.system_time(:second)

    case Enum.split_while(tickets, fn {ticket, recv} -> expired?(ticket, recv, now) end) do
      {_expired, [{ticket, _recv} | rest]} -> {ticket, %{data | tickets: rest}}
      {_all_expired, []} -> {nil, %{data | tickets: []}}
    end
  end

  defp expired?(ticket, received_at, now) do
    case SessionTicket.lifetime(ticket) do
      nil -> false
      lifetime -> now - received_at >= lifetime
    end
  end

  defp start_connection(data) do
    {ticket, data} = maybe_pop_ticket(data)

    opts =
      [origin: data.origin, config: data.config, pool_pid: self()]
      |> maybe_put_session_ticket(ticket)

    case DynamicSupervisor.start_child(data.conn_sup, {Connection, opts}) do
      {:ok, pid} ->
        ref = Process.monitor(pid)
        conn_info = %{ref: ref, stream_count: 0, max_streams: 0, state: :connecting}
        connections = Map.put(data.connections, pid, conn_info)
        data = %{data | connections: connections}
        data = if ticket, do: %{data | early_connecting: pid}, else: data
        {:ok, pid, data}

      {:error, reason} ->
        {:error, reason, data}
    end
  end

  defp maybe_pop_ticket(data) do
    if EarlyData.enabled?(data.config), do: pop_ticket(data), else: {nil, data}
  end

  defp maybe_put_session_ticket(opts, nil), do: opts
  defp maybe_put_session_ticket(opts, ticket), do: Keyword.put(opts, :session_ticket, ticket)

  defp clear_early_connecting(%{early_connecting: pid} = data, pid),
    do: %{data | early_connecting: nil}

  defp clear_early_connecting(data, _pid), do: data

  defp maybe_expand_and_pick(data) do
    if map_size(data.connections) < data.max_connections do
      case start_connection(data) do
        {:ok, _pid, data} -> pick_or_pending(data)
        {:error, _reason, _data} -> pick_or_none(data)
      end
    else
      pick_or_none(data)
    end
  end

  defp pick_or_pending(data) do
    case pick_connection(data) do
      {:ok, pid} -> {:ok, pid, data}
      :none_available -> {:pending, data}
    end
  end

  defp pick_or_none(data) do
    case pick_connection(data) do
      {:ok, pid} -> {:ok, pid, data}
      :none_available -> if any_connecting?(data), do: {:pending, data}, else: :none_available
    end
  end

  defp pick_connection(data) do
    data.connections
    |> Enum.reduce(nil, fn
      {pid, %{state: :connected, stream_count: c, max_streams: max}}, nil when c < max ->
        {pid, c}

      {pid, %{state: :connected, stream_count: c, max_streams: max}}, {_, best}
      when c < max and c < best ->
        {pid, c}

      _, acc ->
        acc
    end)
    |> case do
      {pid, _} -> {:ok, pid}
      nil -> :none_available
    end
  end

  defp any_connecting?(data) do
    Enum.any?(data.connections, fn {_pid, %{state: state}} -> state == :connecting end)
  end

  defp mark_draining(data, conn_pid) do
    case data.connections do
      %{^conn_pid => info} ->
        info = %{info | state: :draining}
        %{data | connections: Map.put(data.connections, conn_pid, info)}

      _ ->
        data
    end
  end

  defp mark_connected(data, conn_pid, max) do
    case data.connections do
      %{^conn_pid => info} ->
        info = %{info | state: :connected, max_streams: max}
        %{data | connections: Map.put(data.connections, conn_pid, info)}

      _ ->
        data
    end
  end

  defp dispatch_all_ready(data) do
    case :queue.out(data.waiting) do
      {:empty, _} -> data
      {{:value, entry}, rest} -> dispatch_all_ready_entry(entry, rest, data)
    end
  end

  defp dispatch_all_ready_entry(entry, rest, data) do
    {from, deadline} = entry_from_and_deadline(entry)

    if System.monotonic_time(:millisecond) >= deadline do
      reply_timeout(from, entry_timeout(entry, data), data)
      dispatch_all_ready(%{data | waiting: rest})
    else
      dispatch_all_ready_pick(entry, rest, data)
    end
  end

  defp dispatch_all_ready_pick(entry, rest, data) do
    case pick_connection(data) do
      {:ok, conn_pid} ->
        data = dispatch_entry(entry, conn_pid, %{data | waiting: rest})
        dispatch_all_ready(data)

      :none_available ->
        data
    end
  end

  defp forward_request(conn_pid, from, method, path, headers, body, opts, data) do
    timeout = Keyword.get(opts, :receive_timeout, 15_000)
    send(conn_pid, {:forward_request, from, method, path, headers, body, timeout})
    update_connection_stream_count(data, conn_pid, 1)
  end

  defp route_first_request(from, method, path, headers, body, opts, data) do
    if data.early_connecting && EarlyData.eligible?(method, opts, data.config) do
      forward_early_request(data.early_connecting, from, method, path, headers, body, opts, data)
    else
      enqueue(from, :buffered, method, path, headers, body, opts, data)
    end
  end

  defp route_request_normally(from, method, path, headers, body, opts, data) do
    case maybe_expand_and_pick(data) do
      {:ok, conn_pid, data} ->
        data = forward_request(conn_pid, from, method, path, headers, body, opts, data)
        {:keep_state, data}

      {:pending, data} ->
        {:keep_state, enqueue(from, :buffered, method, path, headers, body, opts, data)}

      :none_available ->
        {:keep_state, enqueue(from, :buffered, method, path, headers, body, opts, data)}
    end
  end

  defp forward_early_request(conn_pid, from, method, path, headers, body, opts, data) do
    timeout = Keyword.get(opts, :receive_timeout, 15_000)
    send(conn_pid, {:forward_early_request, from, method, path, headers, body, timeout})
    update_connection_stream_count(data, conn_pid, 1)
  end

  defp forward_stream(conn_pid, from, method, path, headers, body, opts, data) do
    timeout = Keyword.get(opts, :receive_timeout, 15_000)
    send(conn_pid, {:forward_stream, from, method, path, headers, body, timeout})
    update_connection_stream_count(data, conn_pid, 1)
  end

  defp forward_open_channel(conn_pid, from, method, path, headers, channel_opts, data) do
    send(conn_pid, {:forward_open_channel, from, method, path, headers, channel_opts})
    update_connection_stream_count(data, conn_pid, 1)
  end

  defp enqueue_channel(from, method, path, headers, channel_opts, data) do
    timeout = data.checkout_timeout
    deadline = System.monotonic_time(:millisecond) + timeout

    entry =
      {:datagram_channel, from, method, path, headers, nil, [channel_opts: channel_opts],
       deadline}

    schedule_sweep()
    %{data | waiting: :queue.in(entry, data.waiting)}
  end

  defp enqueue(from, mode, method, path, headers, body, opts, data) do
    timeout = Keyword.get(opts, :checkout_timeout, data.checkout_timeout)
    deadline = System.monotonic_time(:millisecond) + timeout
    entry = {mode, from, method, path, headers, body, opts, deadline}
    schedule_sweep()
    %{data | waiting: :queue.in(entry, data.waiting)}
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
      reply_timeout(from, entry_timeout(entry, data), data)
      maybe_dequeue(%{data | waiting: rest})
    else
      dispatch_queued(entry, rest, data)
    end
  end

  defp dispatch_queued(entry, rest, data) do
    case pick_connection(data) do
      {:ok, conn_pid} ->
        dispatch_entry(entry, conn_pid, %{data | waiting: rest})

      :none_available ->
        data
    end
  end

  defp dispatch_entry(
         {:buffered, from, method, path, headers, body, opts, _deadline},
         conn_pid,
         data
       ) do
    forward_request(conn_pid, from, method, path, headers, body, opts, data)
  end

  defp dispatch_entry(
         {:streaming, from, method, path, headers, body, opts, _deadline},
         conn_pid,
         data
       ) do
    forward_stream(conn_pid, from, method, path, headers, body, opts, data)
  end

  defp dispatch_entry(
         {:datagram_channel, from, method, path, headers, _body, opts, _deadline},
         conn_pid,
         data
       ) do
    channel_opts = Keyword.get(opts, :channel_opts, [])
    forward_open_channel(conn_pid, from, method, path, headers, channel_opts, data)
  end

  defp entry_from_and_deadline({_mode, from, _, _, _, _, _, deadline}), do: {from, deadline}

  defp entry_timeout({_mode, _, _, _, _, _, opts, _}, data),
    do: Keyword.get(opts, :checkout_timeout, data.checkout_timeout)

  defp reply_timeout(from, timeout, data) do
    origin_str = format_origin(data.origin)

    GenStateMachine.reply(
      from,
      {:error, CheckoutTimeout.exception(origin: origin_str, timeout: timeout)}
    )
  end

  defp sweep_expired(data) do
    now = System.monotonic_time(:millisecond)

    {expired, remaining} =
      data.waiting
      |> :queue.to_list()
      |> Enum.split_with(fn entry ->
        {_from, deadline} = entry_from_and_deadline(entry)
        now >= deadline
      end)

    Enum.each(expired, fn entry ->
      {from, _deadline} = entry_from_and_deadline(entry)
      reply_timeout(from, entry_timeout(entry, data), data)
    end)

    %{data | waiting: :queue.from_list(remaining)}
  end

  defp schedule_sweep do
    Process.send_after(self(), :sweep_queue, 1_000)
  end

  defp update_connection_stream_count(data, conn_pid, delta) do
    case data.connections do
      %{^conn_pid => info} ->
        new_count = max(0, info.stream_count + delta)
        put_in(data.connections[conn_pid].stream_count, new_count)

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
  defp format_origin(other), do: inspect(other)

  defp lookup_first_worker(%__MODULE__{connections: conns}) when map_size(conns) == 0, do: nil

  defp lookup_first_worker(%__MODULE__{connections: conns}) do
    conns |> Map.keys() |> hd()
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(data, opts) do
      fields = [
        origin: data.origin,
        connections: map_size(data.connections),
        max_connections: data.max_connections,
        waiting: :queue.len(data.waiting)
      ]

      container_doc("#Quiver.Pool.HTTP3<", fields, ">", opts, &keyword_field/2, separator: ",")
    end

    defp keyword_field({key, value}, opts) do
      concat([Atom.to_string(key), ": ", to_doc(value, opts)])
    end
  end
end
