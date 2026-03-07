defmodule Quiver.Pool.HTTP1 do
  @moduledoc """
  HTTP/1 connection pool backed by NimblePool.

  Connections are created lazily in the caller's process on first checkout.
  Subsequent checkouts reuse idle connections. Dead and idle-timed-out
  connections are evicted via handle_ping. Stats tracked in ETS.
  """

  @behaviour NimblePool
  @behaviour Quiver.Pool

  alias Quiver.Conn.HTTP1
  alias Quiver.Error.CheckoutTimeout
  alias Quiver.Error.StreamError
  alias Quiver.Proxy
  alias Quiver.StreamResponse
  alias Quiver.Telemetry
  alias Quiver.Transport.SSL

  defstruct [:origin, :config, :stats_table]

  @type t :: %__MODULE__{
          origin: origin() | nil,
          config: map() | nil,
          stats_table: :ets.table() | nil
        }

  @type origin :: {:http | :https, String.t(), :inet.port_number()}

  @doc false
  def child_spec(opts) do
    %{
      id: {__MODULE__, Keyword.fetch!(opts, :origin)},
      start: {__MODULE__, :start_link, [opts]},
      type: :worker
    }
  end

  @spec start_link(keyword()) :: GenServer.on_start() | {:error, term()}
  def start_link(opts) do
    {origin, opts} = Keyword.pop!(opts, :origin)
    {pool_opts, nimble_opts} = Keyword.pop(opts, :pool_opts, [])

    init_arg = %__MODULE__{origin: origin, config: pool_opts}

    nimble_opts =
      Keyword.merge(nimble_opts,
        worker: {__MODULE__, init_arg},
        pool_size: Keyword.get(pool_opts, :size, 10),
        lazy: true,
        worker_idle_timeout: Keyword.get(pool_opts, :ping_interval, 5_000)
      )

    NimblePool.start_link(nimble_opts)
  end

  @impl Quiver.Pool
  @spec request(
          pid(),
          Quiver.Conn.method(),
          String.t(),
          Quiver.Conn.headers(),
          iodata() | nil,
          keyword()
        ) ::
          {:ok, Quiver.Response.t()} | {:error, term()}
  def request(pool, method, path, headers, body, opts \\ []) do
    timeout = Keyword.get(opts, :receive_timeout, default_timeout(pool))
    do_checkout(pool, method, path, headers, body, timeout)
  end

  @impl Quiver.Pool
  @spec stream_request(
          pid(),
          Quiver.Conn.method(),
          String.t(),
          Quiver.Conn.headers(),
          iodata() | nil,
          keyword()
        ) ::
          {:ok, StreamResponse.t()} | {:error, term()}
  def stream_request(pool, method, path, headers, body, opts \\ []) do
    timeout = Keyword.get(opts, :receive_timeout, default_timeout(pool))
    do_stream_checkout(pool, method, path, headers, body, timeout)
  end

  @impl Quiver.Pool
  @spec stats(pid()) :: %{
          idle: non_neg_integer(),
          active: non_neg_integer(),
          queued: non_neg_integer()
        }
  def stats(pool) do
    table = get_stats_table(pool)

    %{
      idle: ets_counter(table, :idle),
      active: ets_counter(table, :active),
      queued: ets_counter(table, :queued)
    }
  end

  # -- NimblePool Callbacks --

  @impl NimblePool
  def init_pool(%__MODULE__{} = state) do
    table = :ets.new(:pool_stats, [:set, :public, read_concurrency: true])
    :ets.insert(table, [{:idle, 0}, {:active, 0}, {:queued, 0}])

    :persistent_term.put({__MODULE__, self()}, %{
      stats_table: table,
      origin: state.origin,
      checkout_timeout: Keyword.get(state.config, :checkout_timeout, 5_000)
    })

    {:ok, %{state | stats_table: table}}
  end

  @impl NimblePool
  def init_worker(state) do
    {:ok, :not_connected, state}
  end

  @impl NimblePool
  def handle_checkout(:checkout, _from, :not_connected, state) do
    update_stat(state, :queued, -1)
    update_stat(state, :active, 1)
    {:ok, {:fresh, state.origin, state.config}, :not_connected, state}
  end

  def handle_checkout(:checkout, _from, {conn, _last_used_at}, state) do
    update_stat(state, :queued, -1)
    update_stat(state, :idle, -1)
    update_stat(state, :active, 1)
    {:ok, {:reuse, conn}, {conn, nil}, state}
  end

  @impl NimblePool
  def handle_checkin(:not_connected, _from, _worker, state) do
    update_stat(state, :active, -1)
    {:remove, :connect_failed, state}
  end

  def handle_checkin(conn, _from, _worker, state) do
    if HTTP1.open?(conn) do
      update_stat(state, :active, -1)
      update_stat(state, :idle, 1)
      {:ok, {conn, System.monotonic_time(:millisecond)}, state}
    else
      update_stat(state, :active, -1)
      {:remove, :closed, state}
    end
  end

  @impl NimblePool
  def handle_ping(:not_connected, _state), do: {:remove, :not_connected}

  def handle_ping({conn, last_used_at}, state) do
    elapsed = System.monotonic_time(:millisecond) - last_used_at

    cond do
      elapsed >= Keyword.get(state.config, :idle_timeout, 30_000) ->
        update_stat(state, :idle, -1)
        emit_conn_close(state.origin, :idle_timeout)
        {:remove, :idle_timeout}

      not HTTP1.open?(conn) ->
        update_stat(state, :idle, -1)
        emit_conn_close(state.origin, :dead)
        {:remove, :dead}

      true ->
        {:ok, {conn, last_used_at}}
    end
  end

  @impl NimblePool
  def handle_enqueue(:checkout, state) do
    new_count = update_stat(state, :queued, 1)

    Telemetry.event(
      Telemetry.pool_queue_event(),
      %{queue_length: new_count},
      %{origin: state.origin}
    )

    {:ok, :checkout, state}
  end

  @impl NimblePool
  def handle_cancelled(:queued, state) do
    update_stat(state, :queued, -1)
    :ok
  end

  def handle_cancelled(:checked_out, state) do
    update_stat(state, :active, -1)
    :ok
  end

  @impl NimblePool
  def terminate_pool(_reason, %{state: %__MODULE__{stats_table: table}}) do
    :persistent_term.erase({__MODULE__, self()})
    if table, do: :ets.delete(table)
    :ok
  end

  def terminate_pool(_reason, _state), do: :ok

  @impl NimblePool
  def terminate_worker(_reason, :not_connected, state), do: {:ok, state}

  def terminate_worker(_reason, {conn, _}, state) do
    HTTP1.close(conn)
    {:ok, state}
  end

  # -- Private --

  defp do_checkout(pool, method, path, headers, body, timeout) do
    origin = pool_origin(pool)

    checkout_fn = fn _from, client ->
      case connect_and_request(client, method, path, headers, body) do
        {:ok, conn, response} -> {{:ok, response}, transfer_ownership(conn, pool)}
        {:error, conn, reason} -> {{:error, reason}, conn}
        {:error, reason} -> {{:error, reason}, :not_connected}
      end
    end

    nimble_checkout(pool, checkout_fn, timeout, origin)
  end

  defp do_stream_checkout(pool, method, path, headers, body, timeout) do
    origin = pool_origin(pool)
    caller = self()
    ref = make_ref()

    {:ok, keeper} =
      Task.start(fn ->
        stream_keeper(pool, method, path, headers, body, timeout, caller, ref)
      end)

    receive do
      {^ref, {:ok, conn, status, resp_headers, initial_chunks}} ->
        body_stream = build_body_stream(conn, initial_chunks, ref, keeper)

        {:ok,
         %StreamResponse{
           status: status,
           headers: resp_headers,
           body: body_stream,
           ref: ref
         }}

      {^ref, {:error, reason}} ->
        {:error, reason}
    after
      timeout ->
        send(keeper, {ref, :cancel})

        receive do
          {^ref, _} -> :ok
        after
          0 -> :ok
        end

        {:error, CheckoutTimeout.exception(origin: origin, timeout: timeout)}
    end
  end

  defp stream_keeper(pool, method, path, headers, body, timeout, caller, ref) do
    caller_mon = Process.monitor(caller)

    try do
      NimblePool.checkout!(
        pool,
        :checkout,
        fn _command, client ->
          case open_and_recv_headers(client, method, path, headers, body) do
            {:ok, conn, status, resp_headers, initial_chunks} ->
              conn = transfer_ownership(conn, pool)
              send(caller, {ref, {:ok, conn, status, resp_headers, initial_chunks}})

              receive do
                {^ref, :done, final_conn} ->
                  Process.demonitor(caller_mon, [:flush])
                  {nil, final_conn}

                {^ref, :cancel} ->
                  Process.demonitor(caller_mon, [:flush])
                  {:ok, closed} = HTTP1.close(conn)
                  {nil, closed}

                {:DOWN, ^caller_mon, _, _, _} ->
                  Process.demonitor(caller_mon, [:flush])
                  {:ok, closed} = HTTP1.close(conn)
                  {nil, closed}
              end

            {:error, reason} ->
              Process.demonitor(caller_mon, [:flush])
              send(caller, {ref, {:error, reason}})
              {nil, :not_connected}
          end
        end,
        timeout
      )
    catch
      :exit, _ -> :ok
    end
  end

  defp transfer_ownership(conn, pool) do
    case conn.transport_mod.controlling_process(conn.transport, pool) do
      {:ok, transport} -> %{conn | transport: transport}
      {:error, _transport, :not_owner} -> conn
      {:error, _transport, _reason} -> %{conn | keep_alive: false}
    end
  end

  defp nimble_checkout(pool, checkout_fn, timeout, origin) do
    NimblePool.checkout!(pool, :checkout, checkout_fn, timeout)
  catch
    :exit, {:timeout, _} ->
      {:error, CheckoutTimeout.exception(origin: origin, timeout: timeout)}
  end

  defp connect_and_request(
         {:fresh, {_scheme, _host, _port} = origin, config},
         method,
         path,
         headers,
         {:stream, enumerable}
       ) do
    case instrumented_connect(origin, config) do
      {:ok, conn} -> HTTP1.stream_request(conn, method, path, headers, enumerable)
      {:error, reason} -> {:error, reason}
    end
  end

  defp connect_and_request(
         {:fresh, {_scheme, _host, _port} = origin, config},
         method,
         path,
         headers,
         body
       ) do
    case instrumented_connect(origin, config) do
      {:ok, conn} -> HTTP1.request(conn, method, path, headers, body)
      {:error, reason} -> {:error, reason}
    end
  end

  defp connect_and_request({:reuse, conn}, method, path, headers, {:stream, enumerable}) do
    HTTP1.stream_request(conn, method, path, headers, enumerable)
  end

  defp connect_and_request({:reuse, conn}, method, path, headers, body) do
    HTTP1.request(conn, method, path, headers, body)
  end

  defp open_and_recv_headers({:fresh, origin, config}, method, path, headers, body) do
    case instrumented_connect(origin, config) do
      {:ok, conn} -> do_open_and_recv(conn, method, path, headers, body)
      {:error, reason} -> {:error, reason}
    end
  end

  defp open_and_recv_headers({:reuse, conn}, method, path, headers, body) do
    do_open_and_recv(conn, method, path, headers, body)
  end

  defp do_open_and_recv(conn, method, path, headers, body) do
    case HTTP1.open_request(conn, method, path, headers, body) do
      {:ok, conn, _ref} -> HTTP1.recv_response_headers(conn)
      {:error, _conn, reason} -> {:error, reason}
    end
  end

  defp build_body_stream(conn, initial_chunks, ref, keeper) do
    Stream.resource(
      fn -> {conn, initial_chunks} end,
      fn
        {conn, [chunk | rest]} ->
          {[chunk], {conn, rest}}

        {conn, []} ->
          case HTTP1.recv_body_chunk(conn) do
            {:ok, conn, chunk} -> {[chunk], {conn, []}}
            {:done, conn} -> {:halt, conn}
            {:error, _conn, reason} -> raise StreamError.exception(reason: reason)
          end
      end,
      fn
        {halted_conn, _} ->
          {:ok, closed} = HTTP1.close(halted_conn)
          send(keeper, {ref, :done, closed})

        done_conn ->
          send(keeper, {ref, :done, done_conn})
      end
    )
  end

  defp instrumented_connect({scheme, host, port} = origin, config) do
    start_time = System.monotonic_time()
    conn_meta = %{origin: origin, scheme: scheme}

    Telemetry.event([:quiver, :conn, :start], %{system_time: System.system_time()}, conn_meta)

    result =
      case Keyword.get(config, :proxy) do
        nil -> direct_connect(scheme, host, port, config)
        proxy_config -> proxy_connect(scheme, host, port, config, proxy_config)
      end

    duration = System.monotonic_time() - start_time

    case result do
      {:ok, conn} ->
        Telemetry.event([:quiver, :conn, :stop], %{duration: duration}, conn_meta)
        {:ok, conn}

      {:error, reason} ->
        Telemetry.event(
          [:quiver, :conn, :stop],
          %{duration: duration},
          Map.put(conn_meta, :error, reason)
        )

        {:error, reason}
    end
  end

  defp direct_connect(scheme, host, port, config) do
    uri = %URI{scheme: to_string(scheme), host: host, port: port}
    HTTP1.connect(uri, config)
  end

  defp proxy_connect(:https, host, port, config, proxy_config) do
    proxy_host = Keyword.fetch!(proxy_config, :host)
    proxy_port = Keyword.fetch!(proxy_config, :port)
    proxy_headers = Keyword.get(proxy_config, :headers, [])
    connect_timeout = Keyword.get(config, :connect_timeout, 5_000)

    proxy_opts = [
      headers: proxy_headers,
      connect_timeout: connect_timeout
    ]

    with {:ok, tcp_transport} <-
           Proxy.connect_tunnel(proxy_host, proxy_port, host, port, proxy_opts),
         {:ok, ssl_transport} <- SSL.upgrade(tcp_transport.socket, host, port, config) do
      recv_timeout = Keyword.get(config, :recv_timeout, 15_000)

      {:ok,
       %HTTP1{
         transport: ssl_transport,
         transport_mod: SSL,
         host: host,
         port: port,
         scheme: :https,
         recv_timeout: recv_timeout
       }}
    end
  end

  defp proxy_connect(:http, host, port, config, _proxy_config) do
    direct_connect(:http, host, port, config)
  end

  defp emit_conn_close(origin, reason) do
    Telemetry.event(
      Telemetry.conn_close_event(),
      %{system_time: System.system_time()},
      %{origin: origin, reason: reason}
    )
  end

  defp update_stat(%{stats_table: table}, key, delta) do
    :ets.update_counter(table, key, delta)
  end

  defp ets_counter(table, key) do
    [{^key, val}] = :ets.lookup(table, key)
    val
  end

  defp pool_origin(pool) do
    case :persistent_term.get({__MODULE__, pool}, nil) do
      %{origin: {scheme, host, port}} -> "#{scheme}://#{host}:#{port}"
      nil -> "unknown"
    end
  end

  defp default_timeout(pool) do
    case :persistent_term.get({__MODULE__, pool}, nil) do
      %{checkout_timeout: timeout} -> timeout
      nil -> 5_000
    end
  end

  defp get_stats_table(pool) do
    %{stats_table: table} = :persistent_term.get({__MODULE__, pool})
    table
  end
end
