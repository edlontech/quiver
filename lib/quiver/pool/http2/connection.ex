defmodule Quiver.Pool.HTTP2.Connection do
  @moduledoc """
  gen_state_machine process owning a single HTTP/2 connection.

  Manages stream multiplexing, caller monitoring, and GOAWAY drain logic.
  The process transitions from :connected to :draining when a GOAWAY is received
  or the server closes the connection, completing in-flight requests before stopping.
  """

  use GenStateMachine, callback_mode: [:state_functions, :state_enter]

  @dialyzer {:no_opaque, connected: 3}

  alias Quiver.Conn.HTTP2, as: H2
  alias Quiver.Error.ProtocolViolation
  alias Quiver.Proxy
  alias Quiver.Response
  alias Quiver.Transport.SSL

  defstruct [
    :conn,
    :origin,
    :config,
    :pool_pid,
    requests: %{},
    monitors: %{},
    write_queue: []
  ]

  @type t :: %__MODULE__{
          conn: Quiver.Conn.HTTP2.t() | nil,
          origin: term(),
          config: keyword(),
          pool_pid: pid() | nil,
          requests: map(),
          monitors: map(),
          write_queue: [iodata()]
        }

  @stream_idle_timeout 30_000

  @doc "Starts the connection worker and performs the HTTP/2 handshake."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenStateMachine.start_link(__MODULE__, opts)
  end

  @doc "Returns true if the connection is open and accepting new streams."
  @spec open?(pid()) :: boolean()
  def open?(pid) do
    GenStateMachine.call(pid, :open?)
  catch
    :exit, _ -> false
  end

  @doc "Returns the number of stream slots available on this connection."
  @spec available_streams(pid()) :: non_neg_integer()
  def available_streams(pid) do
    GenStateMachine.call(pid, :available_streams)
  catch
    :exit, _ -> 0
  end

  @doc "Returns the server's max concurrent streams setting."
  @spec max_streams(pid()) :: non_neg_integer()
  def max_streams(pid) do
    GenStateMachine.call(pid, :max_streams)
  catch
    :exit, _ -> 0
  end

  @doc "Closes the connection, failing any in-flight requests."
  @spec close(pid()) :: :ok
  def close(pid) do
    GenStateMachine.call(pid, :close)
  end

  @doc "Sends an HTTP/2 request and blocks until the response is complete."
  @spec request(pid(), atom(), String.t(), list(), iodata() | nil, keyword()) ::
          {:ok, Response.t()} | {:error, term()}
  def request(pid, method, path, headers, body, opts \\ []) do
    timeout = Keyword.get(opts, :receive_timeout, 15_000)
    GenStateMachine.call(pid, {:request, method, path, headers, body}, timeout)
  catch
    :exit, {:timeout, _} -> {:error, :recv_timeout}
  end

  @impl true
  def init(opts) do
    origin = Keyword.fetch!(opts, :origin)
    config = Keyword.get(opts, :config, [])
    pool_pid = Keyword.get(opts, :pool_pid)

    case connect_h2(origin, config) do
      {:ok, conn} ->
        {:ok, transport} = conn.transport_mod.controlling_process(conn.transport, self())
        conn = put_in(conn.transport, transport)
        {:ok, transport} = conn.transport_mod.activate(conn.transport)
        conn = put_in(conn.transport, transport)

        data = %__MODULE__{
          conn: conn,
          origin: origin,
          config: config,
          pool_pid: pool_pid
        }

        {:ok, :connected, data}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  defp connect_h2({scheme, host, port}, config) do
    case Keyword.get(config, :proxy) do
      nil ->
        uri = %URI{scheme: Atom.to_string(scheme), host: host, port: port}
        H2.connect(uri, config)

      proxy_config when scheme == :https ->
        proxy_connect_h2(host, port, config, proxy_config)

      _proxy_config ->
        uri = %URI{scheme: Atom.to_string(scheme), host: host, port: port}
        H2.connect(uri, config)
    end
  end

  defp proxy_connect_h2(host, port, config, proxy_config) do
    proxy_host = Keyword.fetch!(proxy_config, :host)
    proxy_port = Keyword.fetch!(proxy_config, :port)
    proxy_headers = Keyword.get(proxy_config, :headers, [])
    connect_timeout = Keyword.get(config, :connect_timeout, 5_000)

    proxy_opts = [
      headers: proxy_headers,
      connect_timeout: connect_timeout
    ]

    ssl_opts = Keyword.put(config, :alpn_advertised_protocols, ["h2"])

    with {:ok, tcp_transport} <-
           Proxy.connect_tunnel(proxy_host, proxy_port, host, port, proxy_opts),
         {:ok, ssl_transport} <- SSL.upgrade(tcp_transport.socket, host, port, ssl_opts) do
      case SSL.negotiated_protocol(ssl_transport) do
        "h2" ->
          conn = %H2{
            transport: ssl_transport,
            transport_mod: SSL,
            host: host,
            port: port,
            scheme: :https,
            recv_timeout: Keyword.get(config, :recv_timeout, 15_000),
            encode_table: HPAX.new(4096),
            decode_table: HPAX.new(4096)
          }

          H2.perform_handshake(conn)

        _other ->
          SSL.close(ssl_transport)

          {:error, ProtocolViolation.exception(message: "server did not negotiate h2 via ALPN")}
      end
    end
  end

  # -- :connected state --

  def connected(:enter, _old_state, _data), do: :keep_state_and_data

  def connected({:call, from}, :open?, _data) do
    {:keep_state_and_data, [{:reply, from, true}]}
  end

  def connected({:call, from}, :available_streams, data) do
    count = H2.max_concurrent_streams(data.conn) - H2.open_request_count(data.conn)
    {:keep_state_and_data, [{:reply, from, count}]}
  end

  def connected({:call, from}, :max_streams, data) do
    {:keep_state_and_data, [{:reply, from, H2.max_concurrent_streams(data.conn)}]}
  end

  def connected({:call, from}, :close, data) do
    {:ok, conn} = H2.close(data.conn)
    {:stop_and_reply, :normal, [{:reply, from, :ok}], %{data | conn: conn}}
  end

  def connected({:call, {caller_pid, _tag} = from}, {:request, method, path, headers, body}, data) do
    case H2.open_request(data.conn, method, path, headers, body) do
      {:ok, conn, ref} ->
        mon = Process.monitor(caller_pid)
        request = %{from: from, caller_pid: caller_pid, monitor: mon, acc: []}
        requests = Map.put(data.requests, ref, request)
        monitors = Map.put(data.monitors, mon, ref)
        {:keep_state, %{data | conn: conn, requests: requests, monitors: monitors}}

      {:error, conn, reason} ->
        {:keep_state, %{data | conn: conn}, [{:reply, from, {:error, reason}}]}
    end
  end

  def connected(
        :info,
        {:forward_request, from, method, path, headers, {:stream, enumerable}, _timeout},
        data
      ) do
    {caller_pid, _tag} = from

    case H2.prepare_stream_request(data.conn, method, path, headers) do
      {:ok, conn, ref, header_frames} ->
        mon = Process.monitor(caller_pid)
        stream_id = Map.fetch!(conn.ref_to_stream_id, ref)

        worker = self()

        {:ok, task_pid} =
          Task.start_link(fn ->
            stream_enumerable(worker, stream_id, enumerable)
          end)

        request = %{
          from: from,
          caller_pid: caller_pid,
          monitor: mon,
          acc: [],
          stream_task: task_pid
        }

        requests = Map.put(data.requests, ref, request)
        monitors = Map.put(data.monitors, mon, ref)
        data = %{data | conn: conn, requests: requests, monitors: monitors}
        schedule_flush(data, header_frames)

      {:error, conn, reason} ->
        GenStateMachine.reply(from, {:error, reason})
        if data.pool_pid, do: send(data.pool_pid, {:stream_open_failed, self()})
        {:keep_state, %{data | conn: conn}}
    end
  end

  def connected(:info, {:forward_request, from, method, path, headers, body, _timeout}, data) do
    {caller_pid, _tag} = from

    case H2.prepare_request(data.conn, method, path, headers, body) do
      {:ok, conn, ref, frames} ->
        mon = Process.monitor(caller_pid)
        request = %{from: from, caller_pid: caller_pid, monitor: mon, acc: []}
        requests = Map.put(data.requests, ref, request)
        monitors = Map.put(data.monitors, mon, ref)
        data = %{data | conn: conn, requests: requests, monitors: monitors}
        schedule_flush(data, frames)

      {:error, conn, reason} ->
        GenStateMachine.reply(from, {:error, reason})
        if data.pool_pid, do: send(data.pool_pid, {:stream_open_failed, self()})
        {:keep_state, %{data | conn: conn}}
    end
  end

  def connected(:info, {:forward_stream, from, method, path, headers, body, _timeout}, data) do
    {caller_pid, _tag} = from

    case H2.prepare_request(data.conn, method, path, headers, body) do
      {:ok, conn, ref, frames} ->
        mon = Process.monitor(caller_pid)

        request = %{
          from: from,
          caller_pid: caller_pid,
          monitor: mon,
          mode: :streaming,
          phase: :awaiting_headers,
          status: nil,
          headers: [],
          trailers: [],
          pending_data: :queue.new(),
          demand_pid: nil,
          idle_timer: nil
        }

        requests = Map.put(data.requests, ref, request)
        monitors = Map.put(data.monitors, mon, ref)
        data = %{data | conn: conn, requests: requests, monitors: monitors}
        schedule_flush(data, frames)

      {:error, conn, reason} ->
        GenStateMachine.reply(from, {:error, reason})
        if data.pool_pid, do: send(data.pool_pid, {:stream_open_failed, self()})
        {:keep_state, %{data | conn: conn}}
    end
  end

  def connected(:info, {:demand, ref, consumer_pid}, data) do
    handle_demand(ref, consumer_pid, data, :connected)
  end

  def connected(:info, {:cancel_stream, ref, _consumer_pid}, data) do
    case Map.pop(data.requests, ref) do
      {nil, _} ->
        :keep_state_and_data

      {%{mode: :streaming, monitor: mon} = req, requests} ->
        cancel_idle_timer(req)
        Process.demonitor(mon, [:flush])
        conn_result = H2.cancel(data.conn, ref)
        conn = elem(conn_result, 1)
        monitors = Map.delete(data.monitors, mon)
        data = %{data | conn: conn, requests: requests, monitors: monitors}
        if data.pool_pid, do: send(data.pool_pid, {:stream_done, self()})
        {:keep_state, data}

      {_, _} ->
        :keep_state_and_data
    end
  end

  def connected(:info, {:stream_idle_timeout, ref}, data) do
    case Map.pop(data.requests, ref) do
      {nil, _} ->
        :keep_state_and_data

      {%{mode: :streaming, demand_pid: demand_pid, monitor: mon}, requests} ->
        Process.demonitor(mon, [:flush])
        if demand_pid, do: send(demand_pid, {:error, ref, :idle_timeout})
        conn_result = H2.cancel(data.conn, ref)
        conn = elem(conn_result, 1)
        monitors = Map.delete(data.monitors, mon)
        data = %{data | conn: conn, requests: requests, monitors: monitors}
        if data.pool_pid, do: send(data.pool_pid, {:stream_done, self()})
        {:keep_state, data}

      {_, _} ->
        :keep_state_and_data
    end
  end

  def connected(:info, {:stream_chunk, stream_id, chunk}, data) do
    case find_ref_by_stream_id(data.conn, stream_id) do
      nil ->
        :keep_state_and_data

      ref ->
        case H2.prepare_stream_data(data.conn, ref, chunk) do
          {:ok, conn, frames} ->
            schedule_flush(%{data | conn: conn}, frames)

          {:would_block, conn, frames} ->
            schedule_flush(%{data | conn: conn}, frames)
        end
    end
  end

  def connected(:info, {:stream_done, stream_id}, data) do
    case find_ref_by_stream_id(data.conn, stream_id) do
      nil ->
        :keep_state_and_data

      ref ->
        case H2.prepare_stream_end(data.conn, ref) do
          {:ok, conn, frame} ->
            schedule_flush(%{data | conn: conn}, frame)

          {:error, conn, _reason} ->
            {:keep_state, %{data | conn: conn}}
        end
    end
  end

  def connected(:info, :flush_writes, data) do
    flush_write_queue(data)
  end

  def connected(:info, {:DOWN, mon, :process, _pid, _reason}, data) do
    handle_caller_down(mon, data, :connected)
  end

  def connected(:info, msg, data) do
    case process_transport_msg(msg, data) do
      {:ok, data, :goaway} -> {:next_state, :draining, data}
      {:ok, data, _conn_state} -> {:keep_state, data}
      {:error, data, reason} -> {:stop, {:shutdown, reason}, data}
      :unknown -> :keep_state_and_data
    end
  end

  # -- :draining state --

  def draining(:enter, _old_state, data) do
    if data.pool_pid, do: send(data.pool_pid, {:connection_draining, self()})

    if map_size(data.requests) == 0 do
      {:stop, :normal, data}
    else
      :keep_state_and_data
    end
  end

  def draining({:call, from}, :open?, _data) do
    {:keep_state_and_data, [{:reply, from, false}]}
  end

  def draining({:call, from}, :available_streams, _data) do
    {:keep_state_and_data, [{:reply, from, 0}]}
  end

  def draining({:call, from}, :max_streams, data) do
    {:keep_state_and_data, [{:reply, from, H2.max_concurrent_streams(data.conn)}]}
  end

  def draining({:call, from}, :close, data) do
    data = fail_all_callers(data, :connection_closing)
    {:ok, conn} = H2.close(data.conn)
    {:stop_and_reply, :normal, [{:reply, from, :ok}], %{data | conn: conn}}
  end

  def draining({:call, from}, {:request, _method, _path, _headers, _body}, _data) do
    {:keep_state_and_data, [{:reply, from, {:error, :connection_draining}}]}
  end

  def draining(:info, {:forward_request, from, _method, _path, _headers, _body, _timeout}, _data) do
    GenStateMachine.reply(from, {:error, :connection_draining})
    :keep_state_and_data
  end

  def draining(:info, {:forward_stream, from, _method, _path, _headers, _body, _timeout}, _data) do
    GenStateMachine.reply(from, {:error, :connection_draining})
    :keep_state_and_data
  end

  def draining(:info, {:demand, ref, consumer_pid}, data) do
    handle_demand(ref, consumer_pid, data, :draining)
  end

  def draining(:info, {:cancel_stream, ref, _consumer_pid}, data) do
    case Map.pop(data.requests, ref) do
      {nil, _} ->
        maybe_stop_draining(data, :draining)

      {%{mode: :streaming, monitor: mon} = req, requests} ->
        cancel_idle_timer(req)
        Process.demonitor(mon, [:flush])
        conn_result = H2.cancel(data.conn, ref)
        conn = elem(conn_result, 1)
        monitors = Map.delete(data.monitors, mon)
        data = %{data | conn: conn, requests: requests, monitors: monitors}
        if data.pool_pid, do: send(data.pool_pid, {:stream_done, self()})
        maybe_stop_draining(data, :draining)

      {_, _} ->
        maybe_stop_draining(data, :draining)
    end
  end

  def draining(:info, {:stream_idle_timeout, ref}, data) do
    case Map.pop(data.requests, ref) do
      {nil, _} ->
        maybe_stop_draining(data, :draining)

      {%{mode: :streaming, demand_pid: demand_pid, monitor: mon}, requests} ->
        Process.demonitor(mon, [:flush])
        if demand_pid, do: send(demand_pid, {:error, ref, :idle_timeout})
        conn_result = H2.cancel(data.conn, ref)
        conn = elem(conn_result, 1)
        monitors = Map.delete(data.monitors, mon)
        data = %{data | conn: conn, requests: requests, monitors: monitors}
        maybe_stop_draining(data, :draining)

      {_, _} ->
        maybe_stop_draining(data, :draining)
    end
  end

  def draining(:info, {:stream_chunk, stream_id, chunk}, data) do
    case find_ref_by_stream_id(data.conn, stream_id) do
      nil ->
        :keep_state_and_data

      ref ->
        case H2.prepare_stream_data(data.conn, ref, chunk) do
          {:ok, conn, frames} ->
            schedule_flush(%{data | conn: conn}, frames)

          {:would_block, conn, frames} ->
            schedule_flush(%{data | conn: conn}, frames)
        end
    end
  end

  def draining(:info, {:stream_done, stream_id}, data) do
    case find_ref_by_stream_id(data.conn, stream_id) do
      nil ->
        :keep_state_and_data

      ref ->
        case H2.prepare_stream_end(data.conn, ref) do
          {:ok, conn, frame} ->
            schedule_flush(%{data | conn: conn}, frame)

          {:error, conn, _reason} ->
            {:keep_state, %{data | conn: conn}}
        end
    end
  end

  def draining(:info, :flush_writes, data) do
    flush_write_queue(data)
  end

  def draining(:info, {:DOWN, mon, :process, _pid, _reason}, data) do
    handle_caller_down(mon, data, :draining)
  end

  def draining(:info, msg, data) do
    case process_transport_msg(msg, data) do
      {:ok, data, _conn_state} when map_size(data.requests) == 0 -> {:stop, :normal, data}
      {:ok, data, _conn_state} -> {:keep_state, data}
      {:error, data, reason} -> {:stop, {:shutdown, reason}, data}
      :unknown -> :keep_state_and_data
    end
  end

  # -- Private helpers --

  defp process_transport_msg(msg, data) do
    case H2.stream(data.conn, msg) do
      {:ok, conn, fragments} ->
        {:ok, transport} = conn.transport_mod.activate(conn.transport)
        conn = put_in(conn.transport, transport)
        {:ok, dispatch_fragments(%{data | conn: conn}, fragments), conn.state}

      {:error, conn, fragments} when is_list(fragments) ->
        data = dispatch_fragments(%{data | conn: conn}, fragments)
        {:error, fail_all_callers(data, :connection_closed), :connection_closed}

      {:error, conn, reason} ->
        {:error, fail_all_callers(%{data | conn: conn}, reason), reason}

      :unknown ->
        :unknown
    end
  end

  defp dispatch_fragments(data, fragments) do
    Enum.reduce(fragments, data, &dispatch_fragment(&2, &1))
  end

  defp dispatch_fragment(data, {:done, ref}) do
    case Map.pop(data.requests, ref) do
      {nil, _requests} ->
        data

      {%{mode: :streaming} = req, requests} ->
        finish_streaming_done(data, ref, req, requests)

      {%{from: from, monitor: mon, acc: acc}, requests} ->
        Process.demonitor(mon, [:flush])
        response = assemble_response(Enum.reverse(acc))
        GenStateMachine.reply(from, {:ok, response})
        if data.pool_pid, do: send(data.pool_pid, {:stream_done, self()})
        %{data | requests: requests, monitors: Map.delete(data.monitors, mon)}
    end
  end

  defp dispatch_fragment(data, {:error, ref, reason}) do
    case Map.pop(data.requests, ref) do
      {nil, _requests} ->
        data

      {%{mode: :streaming, phase: :awaiting_headers} = req, requests} ->
        Process.demonitor(req.monitor, [:flush])
        GenStateMachine.reply(req.from, {:error, reason})
        if data.pool_pid, do: send(data.pool_pid, {:stream_done, self()})
        %{data | requests: requests, monitors: Map.delete(data.monitors, req.monitor)}

      {%{mode: :streaming} = req, requests} ->
        Process.demonitor(req.monitor, [:flush])
        cancel_idle_timer(req)
        if req.demand_pid, do: send(req.demand_pid, {:error, ref, reason})
        if data.pool_pid, do: send(data.pool_pid, {:stream_done, self()})
        %{data | requests: requests, monitors: Map.delete(data.monitors, req.monitor)}

      {%{from: from, monitor: mon}, requests} ->
        Process.demonitor(mon, [:flush])
        GenStateMachine.reply(from, {:error, reason})
        if data.pool_pid, do: send(data.pool_pid, {:stream_done, self()})
        %{data | requests: requests, monitors: Map.delete(data.monitors, mon)}
    end
  end

  defp dispatch_fragment(data, {type, ref, value})
       when type in [:status, :headers, :data, :trailers] do
    case Map.get(data.requests, ref) do
      nil ->
        data

      %{mode: :streaming, phase: :awaiting_headers} = req ->
        dispatch_streaming_header_phase(data, ref, req, type, value)

      %{mode: :streaming, phase: :body} = req ->
        dispatch_streaming_body_phase(data, ref, req, type, value)

      request ->
        put_in(data.requests[ref], %{request | acc: [{type, value} | request.acc]})
    end
  end

  defp dispatch_fragment(data, {:pong, _ref}), do: data

  defp finish_streaming_done(data, ref, %{demand_pid: pid} = req, requests) when pid != nil do
    cancel_idle_timer(req)
    Process.demonitor(req.monitor, [:flush])
    if req.trailers != [], do: send(pid, {:trailers, ref, req.trailers})
    send(pid, {:done, ref})
    if data.pool_pid, do: send(data.pool_pid, {:stream_done, self()})
    %{data | requests: requests, monitors: Map.delete(data.monitors, req.monitor)}
  end

  defp finish_streaming_done(data, ref, req, requests) do
    cancel_idle_timer(req)

    phase = if :queue.is_empty(req.pending_data), do: :done_immediate, else: :done_pending
    req = %{req | phase: phase, idle_timer: nil}
    %{data | requests: Map.put(requests, ref, req)}
  end

  defp dispatch_streaming_header_phase(data, ref, req, :status, value) do
    put_in(data.requests[ref], %{req | status: value})
  end

  defp dispatch_streaming_header_phase(data, ref, req, :headers, value) do
    Process.demonitor(req.monitor, [:flush])
    monitors = Map.delete(data.monitors, req.monitor)

    req = %{
      req
      | headers: req.headers ++ value,
        phase: :body,
        idle_timer: schedule_idle_timeout(ref)
    }

    GenStateMachine.reply(req.from, {:ok, req.status, req.headers, ref, self()})
    %{put_in(data.requests[ref], req) | monitors: monitors}
  end

  defp dispatch_streaming_header_phase(data, ref, req, :data, value) do
    put_in(data.requests[ref], %{req | pending_data: :queue.in(value, req.pending_data)})
  end

  defp dispatch_streaming_body_phase(data, ref, req, :data, value) do
    if req.demand_pid != nil do
      send(req.demand_pid, {:chunk, ref, value})
      timer = reschedule_idle_timeout(req.idle_timer, ref)
      put_in(data.requests[ref], %{req | demand_pid: nil, idle_timer: timer})
    else
      put_in(data.requests[ref], %{req | pending_data: :queue.in(value, req.pending_data)})
    end
  end

  defp dispatch_streaming_body_phase(data, ref, req, :trailers, value) do
    put_in(data.requests[ref], %{req | trailers: value})
  end

  defp dispatch_streaming_body_phase(data, _ref, _req, _type, _value), do: data

  defp handle_demand(ref, consumer_pid, data, current_state) do
    case Map.get(data.requests, ref) do
      %{mode: :streaming, phase: :done_immediate} = req ->
        demand_finish_stream(ref, consumer_pid, req, data, current_state)

      %{mode: :streaming, phase: :done_pending} = req ->
        demand_drain_pending(ref, consumer_pid, req, data, current_state)

      %{mode: :streaming, phase: :body} = req ->
        demand_body_chunk(ref, consumer_pid, req, data)

      _ ->
        :keep_state_and_data
    end
  end

  defp demand_finish_stream(ref, consumer_pid, req, data, current_state) do
    Process.demonitor(req.monitor, [:flush])
    if req.trailers != [], do: send(consumer_pid, {:trailers, ref, req.trailers})
    send(consumer_pid, {:done, ref})
    if data.pool_pid, do: send(data.pool_pid, {:stream_done, self()})
    monitors = Map.delete(data.monitors, req.monitor)

    maybe_stop_draining(
      %{data | requests: Map.delete(data.requests, ref), monitors: monitors},
      current_state
    )
  end

  defp demand_drain_pending(ref, consumer_pid, req, data, current_state) do
    case :queue.out(req.pending_data) do
      {{:value, chunk}, rest} ->
        send(consumer_pid, {:chunk, ref, chunk})

        if :queue.is_empty(rest) do
          demand_finish_stream(ref, consumer_pid, req, data, current_state)
        else
          {:keep_state, put_in(data.requests[ref], %{req | pending_data: rest})}
        end

      {:empty, _} ->
        demand_finish_stream(ref, consumer_pid, req, data, current_state)
    end
  end

  defp demand_body_chunk(ref, consumer_pid, req, data) do
    case :queue.out(req.pending_data) do
      {{:value, chunk}, rest} ->
        send(consumer_pid, {:chunk, ref, chunk})
        timer = reschedule_idle_timeout(req.idle_timer, ref)

        {:keep_state, put_in(data.requests[ref], %{req | pending_data: rest, idle_timer: timer})}

      {:empty, _} ->
        timer = reschedule_idle_timeout(req.idle_timer, ref)

        {:keep_state,
         put_in(data.requests[ref], %{req | demand_pid: consumer_pid, idle_timer: timer})}
    end
  end

  defp schedule_flush(data, frames) do
    was_empty = data.write_queue == []
    data = %{data | write_queue: [data.write_queue | frames]}
    if was_empty, do: send(self(), :flush_writes)
    {:keep_state, data}
  end

  defp flush_write_queue(%{write_queue: []} = data) do
    {:keep_state, data}
  end

  defp flush_write_queue(data) do
    case data.conn.transport_mod.send(data.conn.transport, data.write_queue) do
      {:ok, transport} ->
        data = put_in(data.conn.transport, transport)
        {:keep_state, %{data | write_queue: []}}

      {:error, transport, reason} ->
        data = put_in(data.conn.transport, transport)
        {:stop, {:shutdown, reason}, %{data | write_queue: []}}
    end
  end

  defp fail_all_callers(data, reason) do
    Enum.each(data.requests, fn {ref, req} ->
      Process.demonitor(req.monitor, [:flush])
      cancel_idle_timer(req)

      case req do
        %{mode: :streaming, phase: :awaiting_headers, from: from} ->
          GenStateMachine.reply(from, {:error, reason})

        %{mode: :streaming, demand_pid: pid} when pid != nil ->
          send(pid, {:error, ref, reason})

        _ ->
          :ok
      end
    end)

    %{data | requests: %{}, monitors: %{}}
  end

  defp handle_caller_down(mon, data, current_state) do
    case Map.pop(data.monitors, mon) do
      {nil, _} -> :keep_state_and_data
      {ref, monitors} -> cancel_stream(ref, monitors, data, current_state)
    end
  end

  defp cancel_stream(ref, monitors, data, current_state) do
    req = Map.get(data.requests, ref)
    if req, do: cancel_idle_timer(req)

    conn_result = H2.cancel(data.conn, ref)
    conn = elem(conn_result, 1)
    requests = Map.delete(data.requests, ref)
    data = %{data | conn: conn, requests: requests, monitors: monitors}

    if data.pool_pid, do: send(data.pool_pid, {:stream_done, self()})
    maybe_stop_draining(data, current_state)
  end

  defp maybe_stop_draining(data, :draining) when map_size(data.requests) == 0 do
    {:stop, :normal, data}
  end

  defp maybe_stop_draining(data, _state), do: {:keep_state, data}

  defp schedule_idle_timeout(ref) do
    Process.send_after(self(), {:stream_idle_timeout, ref}, @stream_idle_timeout)
  end

  defp reschedule_idle_timeout(nil, ref), do: schedule_idle_timeout(ref)

  defp reschedule_idle_timeout(timer, ref) do
    Process.cancel_timer(timer)
    schedule_idle_timeout(ref)
  end

  defp cancel_idle_timer(%{idle_timer: nil}), do: :ok
  defp cancel_idle_timer(%{idle_timer: timer}), do: Process.cancel_timer(timer)
  defp cancel_idle_timer(_), do: :ok

  defp stream_enumerable(worker, stream_id, enumerable) do
    Enum.each(enumerable, fn chunk ->
      send(worker, {:stream_chunk, stream_id, chunk})
      Process.sleep(0)
    end)

    send(worker, {:stream_done, stream_id})
  end

  defp find_ref_by_stream_id(conn, stream_id) do
    Enum.find_value(conn.ref_to_stream_id, fn {ref, sid} ->
      if sid == stream_id, do: ref
    end)
  end

  defp assemble_response(fragments) do
    {status, headers, trailers, chunks} =
      Enum.reduce(fragments, {nil, [], [], []}, fn
        {:status, s}, {_, h, t, c} -> {s, h, t, c}
        {:headers, h}, {s, hs, t, c} -> {s, hs ++ h, t, c}
        {:trailers, t}, {s, h, _, c} -> {s, h, t, c}
        {:data, d}, {s, h, t, cs} -> {s, h, t, [d | cs]}
      end)

    body = if chunks == [], do: nil, else: IO.iodata_to_binary(:lists.reverse(chunks))

    %Response{status: status, headers: headers, body: body, trailers: trailers}
  end
end
