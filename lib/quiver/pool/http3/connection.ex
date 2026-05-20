defmodule Quiver.Pool.HTTP3.Connection do
  @moduledoc """
  gen_state_machine process owning a single HTTP/3 connection via `:quic_h3`.

  Translates `{:quic_h3, _, _}` events into caller replies. Supports
  buffered request/response, response streaming, request body streaming,
  and GOAWAY-driven connection draining.

  State machine:

      :connecting -> :connected -> :draining

  The worker transitions to `:draining` on receiving a peer-initiated
  `{:quic_h3, _, {:goaway, GoawayId}}` or self-initiated
  `{:quic_h3, _, {:goaway_sent, GoawayId}}` event. While draining, in-flight
  requests with `stream_id < goaway_id` continue to completion; everything
  else fails with `Quiver.Error.H3GoAway`. New `:forward_request` /
  `:forward_stream` messages are refused. The worker stops `:normal` when
  no requests remain.

  Note: request body streaming uses `{:stream_chunk, sid, chunk}` and
  `{:stream_end, sid}` info messages, whereas the HTTP/2 sibling uses
  different naming. Aligning the two is tracked separately.
  """

  use GenStateMachine, callback_mode: [:state_functions, :state_enter]

  @dialyzer {:nowarn_function, init: 1}

  alias Quiver.Conn.HTTP3, as: ConnHTTP3
  alias Quiver.Error.H3GoAway
  alias Quiver.Error.H3StreamError
  alias Quiver.Error.QUICHandshakeFailed
  alias Quiver.Error.QUICTransportError
  alias Quiver.Response

  defstruct [
    :h3_conn,
    :h3_conn_mon,
    :origin,
    :config,
    :pool_pid,
    :handshake_start,
    goaway_id: nil,
    peer_max_streams: 100,
    stream_idle_timeout: 30_000,
    requests: %{},
    monitors: %{},
    stream_to_ref: %{},
    stream_tasks: %{},
    pending_during_connect: []
  ]

  @default_stream_idle_timeout 30_000

  @type origin :: {atom(), String.t(), :inet.port_number()}

  @type t :: %__MODULE__{
          h3_conn: pid() | nil,
          h3_conn_mon: reference() | nil,
          origin: origin(),
          config: keyword(),
          pool_pid: pid() | nil,
          handshake_start: integer() | nil,
          goaway_id: non_neg_integer() | nil,
          peer_max_streams: non_neg_integer(),
          stream_idle_timeout: non_neg_integer(),
          requests: map(),
          monitors: map(),
          stream_to_ref: map(),
          stream_tasks: map(),
          pending_during_connect: [tuple()]
        }

  @doc false
  def child_spec(opts),
    do: %{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}, type: :worker}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts), do: GenStateMachine.start_link(__MODULE__, opts)

  @doc """
  Returns the peer's advertised concurrent stream limit once the connection
  has reached `:connected`. Returns `0` while still handshaking.
  """
  @spec max_streams(pid()) :: non_neg_integer()
  def max_streams(pid), do: GenStateMachine.call(pid, :max_streams)

  @impl true
  def init(opts) do
    {scheme, host, port} = origin = Keyword.fetch!(opts, :origin)
    config = Keyword.get(opts, :config, [])
    pool_pid = Keyword.get(opts, :pool_pid)

    h3_opts = build_h3_opts(config)
    handshake_start = System.monotonic_time()
    emit_start(origin, pool_pid)

    case :quic_h3.connect(host, port, h3_opts) do
      {:ok, h3_conn} ->
        mon = Process.monitor(h3_conn)

        data = %__MODULE__{
          h3_conn: h3_conn,
          h3_conn_mon: mon,
          origin: {scheme, host, port},
          config: config,
          pool_pid: pool_pid,
          handshake_start: handshake_start,
          stream_idle_timeout:
            Keyword.get(config, :stream_idle_timeout, @default_stream_idle_timeout)
        }

        {:ok, :connecting, data}

      {:error, reason} ->
        emit_exception(origin, reason, handshake_start)
        {:stop, QUICHandshakeFailed.exception(origin: origin, reason: reason)}
    end
  end

  defp emit_start(origin, pool_pid) do
    :telemetry.execute(
      [:quiver, :connection, :http3, :start],
      %{system_time: System.system_time()},
      %{origin: origin, pool_pid: pool_pid}
    )
  end

  defp emit_stop(data) do
    duration = System.monotonic_time() - data.handshake_start

    :telemetry.execute(
      [:quiver, :connection, :http3, :stop],
      %{duration: duration},
      %{origin: data.origin, peer_max_streams: data.peer_max_streams}
    )
  end

  defp emit_exception(origin, reason, handshake_start) do
    duration = System.monotonic_time() - handshake_start

    :telemetry.execute(
      [:quiver, :connection, :http3, :exception],
      %{duration: duration},
      %{origin: origin, reason: reason, kind: :error}
    )
  end

  defp emit_draining(data, goaway_id) do
    :telemetry.execute(
      [:quiver, :connection, :http3, :draining],
      %{system_time: System.system_time()},
      %{origin: data.origin, last_stream_id: goaway_id, error_code: nil}
    )
  end

  defp build_h3_opts(config) do
    base = %{
      sync: false,
      alpn: [<<"h3">>],
      verify: Keyword.get(config, :verify, :verify_peer)
    }

    base
    |> maybe_put(:cacerts, Keyword.get(config, :cacerts))
    |> maybe_put(:settings, Keyword.get(config, :h3_settings))
    |> maybe_put(:quic_opts, Keyword.get(config, :quic_opts))
  end

  defp maybe_put(map, _k, nil), do: map
  defp maybe_put(map, _k, :default), do: map
  defp maybe_put(map, _k, v) when is_map(v) and map_size(v) == 0, do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)

  # -- :connecting state --

  def connecting(:enter, _old, _data), do: :keep_state_and_data

  def connecting(:info, {:quic_h3, h3_conn, :connected}, %{h3_conn: h3_conn} = data) do
    fallback = Keyword.get(data.config, :initial_max_streams, 100)
    peer = ConnHTTP3.query_peer_max_streams(h3_conn, fallback)
    Enum.each(Enum.reverse(data.pending_during_connect), &send(self(), &1))
    {:next_state, :connected, %{data | peer_max_streams: peer, pending_during_connect: []}}
  end

  def connecting(:info, {:quic_h3, h3_conn, :closed}, %{h3_conn: h3_conn} = data) do
    emit_exception(data.origin, :closed, data.handshake_start)
    fail_pending(data, QUICHandshakeFailed.exception(origin: data.origin, reason: :closed))
    {:stop, :normal, data}
  end

  def connecting(:info, {:quic_h3, h3_conn, {:error, code, reason}}, %{h3_conn: h3_conn} = data) do
    emit_exception(data.origin, {:error, code, reason}, data.handshake_start)

    fail_pending(
      data,
      QUICHandshakeFailed.exception(origin: data.origin, reason: {:error, code, reason})
    )

    {:stop, :shutdown, data}
  end

  def connecting({:call, from}, :max_streams, _data) do
    {:keep_state_and_data, [{:reply, from, 0}]}
  end

  def connecting(:info, {:forward_request, _from, _m, _p, _h, _b, _t} = msg, data) do
    {:keep_state, %{data | pending_during_connect: [msg | data.pending_during_connect]}}
  end

  def connecting(:info, {:forward_stream, _from, _m, _p, _h, _b, _t} = msg, data) do
    {:keep_state, %{data | pending_during_connect: [msg | data.pending_during_connect]}}
  end

  def connecting(:info, {:DOWN, mon, :process, _, reason}, %{h3_conn_mon: mon} = data) do
    emit_exception(data.origin, reason, data.handshake_start)
    fail_pending(data, QUICHandshakeFailed.exception(origin: data.origin, reason: reason))
    {:stop, :shutdown, data}
  end

  def connecting(:info, {:quic_h3, _, _}, _data), do: :keep_state_and_data
  def connecting(:info, _other, _data), do: :keep_state_and_data

  # -- :connected state --

  def connected(:enter, :connecting, data) do
    emit_stop(data)

    if data.pool_pid do
      send(data.pool_pid, {:connection_ready, self(), data.peer_max_streams})
    end

    :keep_state_and_data
  end

  def connected(:enter, _old, _data), do: :keep_state_and_data

  def connected({:call, from}, :max_streams, %{peer_max_streams: n}) do
    {:keep_state_and_data, [{:reply, from, n}]}
  end

  def connected(:info, {:forward_request, from, method, path, headers, body, _timeout}, data) do
    open_buffered_request(data, from, method, path, headers, body)
  end

  def connected(:info, {:forward_stream, from, method, path, headers, body, _timeout}, data) do
    open_streaming_request(data, from, method, path, headers, body)
  end

  def connected(:info, msg, data), do: dispatch_runtime(:connected, msg, data)

  # -- :draining state --

  def draining(:enter, _old, data) do
    if data.pool_pid, do: send(data.pool_pid, {:connection_draining, self()})

    if map_size(data.requests) == 0 do
      {:stop, :normal, data}
    else
      :keep_state_and_data
    end
  end

  def draining({:call, from}, :max_streams, _data) do
    {:keep_state_and_data, [{:reply, from, 0}]}
  end

  def draining(:info, {:forward_request, from, _m, _p, _h, _b, _t}, data) do
    reject_with_goaway(data, from)
    :keep_state_and_data
  end

  def draining(:info, {:forward_stream, from, _m, _p, _h, _b, _t}, data) do
    reject_with_goaway(data, from)
    :keep_state_and_data
  end

  def draining(:info, msg, data), do: dispatch_runtime(:draining, msg, data)

  # -- shared runtime dispatch --

  defp dispatch_runtime(state, msg, data) do
    case dispatch_event(msg, data) do
      :unhandled -> :keep_state_and_data
      result -> maybe_finalize_draining(state, result, data)
    end
  end

  defp dispatch_event({:demand, ref, consumer_pid}, data),
    do: handle_demand(data, ref, consumer_pid)

  defp dispatch_event({:cancel_stream, ref, _consumer_pid}, data),
    do: handle_cancel_stream(data, ref)

  defp dispatch_event({:stream_idle_timeout, ref}, data),
    do: handle_idle_timeout(data, ref)

  defp dispatch_event({:stream_chunk, sid, chunk}, data),
    do: handle_stream_chunk(data, sid, chunk)

  defp dispatch_event({:stream_end, sid}, data),
    do: handle_stream_end(data, sid)

  defp dispatch_event({:stream_chunk_error, sid, reason}, data),
    do: handle_stream_chunk_error(data, sid, reason)

  defp dispatch_event(
         {:quic_h3, h3_conn, {:response, sid, status, headers}},
         %{h3_conn: h3_conn} = data
       ),
       do: handle_response(data, sid, status, headers)

  defp dispatch_event(
         {:quic_h3, h3_conn, {:data, sid, chunk, false}},
         %{h3_conn: h3_conn} = data
       ),
       do: handle_data_chunk(data, sid, chunk)

  defp dispatch_event({:quic_h3, h3_conn, {:data, sid, chunk, true}}, %{h3_conn: h3_conn} = data),
    do: handle_data_final(data, sid, chunk)

  defp dispatch_event(
         {:quic_h3, h3_conn, {:trailers, sid, trailers}},
         %{h3_conn: h3_conn} = data
       ),
       do: handle_trailers(data, sid, trailers)

  defp dispatch_event(
         {:quic_h3, h3_conn, {:stream_reset, sid, code}},
         %{h3_conn: h3_conn} = data
       ),
       do: handle_stream_reset(data, sid, code)

  defp dispatch_event({:quic_h3, h3_conn, {:goaway, gid}}, %{h3_conn: h3_conn} = data),
    do: handle_goaway(data, gid)

  defp dispatch_event({:quic_h3, h3_conn, {:goaway_sent, gid}}, %{h3_conn: h3_conn} = data),
    do: handle_goaway(data, gid)

  defp dispatch_event({:quic_h3, h3_conn, :closed}, %{h3_conn: h3_conn} = data) do
    data = fail_all(data, QUICTransportError.exception(code: 0, reason: :closed))
    {:stop, :normal, data}
  end

  defp dispatch_event({:quic_h3, h3_conn, {:error, code, reason}}, %{h3_conn: h3_conn} = data) do
    data = fail_all(data, QUICTransportError.exception(code: code, reason: reason))
    {:stop, :shutdown, data}
  end

  defp dispatch_event({:quic_h3, _, _}, _data), do: :keep_state_and_data

  defp dispatch_event({:DOWN, mon, :process, _, reason}, %{h3_conn_mon: mon} = data) do
    data = fail_all(data, QUICTransportError.exception(code: 0, reason: {:h3_conn_down, reason}))
    {:stop, :shutdown, data}
  end

  defp dispatch_event({:DOWN, mon, :process, _, _reason}, data) do
    case Map.fetch(data.monitors, mon) do
      :error -> {:keep_state, %{data | monitors: Map.delete(data.monitors, mon)}}
      {:ok, ref} -> handle_caller_down(data, ref, mon)
    end
  end

  defp dispatch_event(_other, _data), do: :unhandled

  defp maybe_finalize_draining(:draining, {:keep_state, data}, _prev) do
    if map_size(data.requests) == 0 and data.goaway_id != nil do
      {:stop, :normal, data}
    else
      {:keep_state, data}
    end
  end

  defp maybe_finalize_draining(:draining, :keep_state_and_data, prev) do
    if map_size(prev.requests) == 0 and prev.goaway_id != nil do
      {:stop, :normal, prev}
    else
      :keep_state_and_data
    end
  end

  defp maybe_finalize_draining(_state, result, _prev), do: result

  defp handle_goaway(%{goaway_id: existing} = data, gid) when is_integer(existing) do
    effective_gid = min(existing, gid)
    drained = drain_for_goaway(data, effective_gid)
    maybe_drain_transition(drained)
  end

  defp handle_goaway(data, gid) do
    data = drain_for_goaway(data, gid)
    emit_draining(data, gid)
    maybe_drain_transition(data)
  end

  defp maybe_drain_transition(data) do
    if map_size(data.requests) == 0 do
      {:stop, :normal, data}
    else
      {:next_state, :draining, data}
    end
  end

  defp drain_for_goaway(data, gid) do
    {to_fail, to_keep} =
      Enum.split_with(data.requests, fn {_ref, %{stream_id: sid}} -> sid >= gid end)

    Enum.each(to_fail, fn {ref, req} ->
      cancel_idle_timer(req)
      err = H3GoAway.exception(goaway_id: gid, stream_id: req.stream_id, unprocessed_stream: true)
      reply_error(req, ref, err)
      Process.demonitor(req.monitor, [:flush])

      case Map.get(data.stream_tasks, ref) do
        nil -> :ok
        task_pid -> kill_stream_task(task_pid)
      end

      _ = :quic_h3.cancel(data.h3_conn, req.stream_id)
      notify_pool(data, :stream_done)
    end)

    failed_mons = Enum.map(to_fail, fn {_ref, %{monitor: m}} -> m end)
    failed_sids = Enum.map(to_fail, fn {_ref, %{stream_id: s}} -> s end)
    failed_refs = Enum.map(to_fail, fn {ref, _req} -> ref end)

    %{
      data
      | goaway_id: gid,
        requests: Map.new(to_keep),
        monitors: Map.drop(data.monitors, failed_mons),
        stream_to_ref: Map.drop(data.stream_to_ref, failed_sids),
        stream_tasks: Map.drop(data.stream_tasks, failed_refs)
    }
  end

  defp reject_with_goaway(data, from) do
    err = H3GoAway.exception(goaway_id: data.goaway_id, stream_id: nil, unprocessed_stream: true)
    GenStateMachine.reply(from, {:error, err})
    notify_pool(data, :stream_open_failed)
  end

  # -- request helpers --

  defp open_buffered_request(data, from, method, path, headers, body) do
    open_request(data, from, method, path, headers, body, :buffered)
  end

  defp open_streaming_request(data, from, method, path, headers, body) do
    open_request(data, from, method, path, headers, body, :streaming)
  end

  defp open_request(data, from, method, path, headers, body, mode) do
    {caller_pid, _tag} = from

    with {:ok, h3_headers} <- ConnHTTP3.build_headers(method, path, headers, data.origin),
         {:ok, sid, task_pid} <- open_stream(data.h3_conn, h3_headers, body) do
      ref = make_ref()
      mon = Process.monitor(caller_pid)
      req = build_request(from, caller_pid, mon, sid, mode)

      data = %{
        data
        | requests: Map.put(data.requests, ref, req),
          monitors: Map.put(data.monitors, mon, ref),
          stream_to_ref: Map.put(data.stream_to_ref, sid, ref),
          stream_tasks: maybe_track_task(data.stream_tasks, ref, task_pid)
      }

      {:keep_state, data}
    else
      {:error, reason} ->
        GenStateMachine.reply(from, {:error, normalize_open_error(reason)})
        notify_pool(data, :stream_open_failed)
        :keep_state_and_data
    end
  end

  defp open_stream(pid, h3_headers, {:stream, enum}) do
    with {:ok, sid} <- :quic_h3.request(pid, h3_headers, %{end_stream: false}) do
      worker = self()
      {:ok, task_pid} = Task.start_link(fn -> stream_enumerable(worker, sid, enum) end)
      {:ok, sid, task_pid}
    end
  end

  defp open_stream(pid, h3_headers, body) do
    opts = if empty_body?(body), do: %{}, else: %{end_stream: false}

    with {:ok, sid} <- :quic_h3.request(pid, h3_headers, opts),
         :ok <- send_body_or_cancel(pid, sid, body) do
      {:ok, sid, nil}
    end
  end

  defp empty_body?(nil), do: true
  defp empty_body?(""), do: true
  defp empty_body?([]), do: true
  defp empty_body?(_), do: false

  defp send_body_or_cancel(pid, sid, body) do
    case maybe_send_body(pid, sid, body) do
      :ok ->
        :ok

      {:error, reason} ->
        _ = :quic_h3.cancel(pid, sid)
        {:error, reason}
    end
  end

  defp stream_enumerable(worker, sid, enum) do
    Enum.each(enum, fn chunk -> send(worker, {:stream_chunk, sid, chunk}) end)
    send(worker, {:stream_end, sid})
  catch
    kind, reason ->
      send(worker, {:stream_chunk_error, sid, {kind, reason, __STACKTRACE__}})
  end

  defp maybe_track_task(tasks, _ref, nil), do: tasks
  defp maybe_track_task(tasks, ref, pid), do: Map.put(tasks, ref, pid)

  defp build_request(from, caller_pid, mon, sid, :buffered) do
    %{
      from: from,
      caller_pid: caller_pid,
      monitor: mon,
      mode: :buffered,
      status: nil,
      headers: [],
      trailers: [],
      acc: [],
      stream_id: sid
    }
  end

  defp build_request(from, caller_pid, mon, sid, :streaming) do
    %{
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
      idle_timer: nil,
      stream_id: sid
    }
  end

  defp normalize_open_error({:forbidden_header, name}),
    do: ArgumentError.exception(message: "forbidden HTTP/3 header: #{name}")

  defp normalize_open_error(%_{} = exception), do: exception
  defp normalize_open_error(other), do: other

  defp maybe_send_body(_pid, _sid, nil), do: :ok
  defp maybe_send_body(_pid, _sid, ""), do: :ok
  defp maybe_send_body(_pid, _sid, []), do: :ok

  defp maybe_send_body(pid, sid, body) when is_binary(body) do
    :quic_h3.send_data(pid, sid, body, true)
  end

  defp maybe_send_body(pid, sid, body) when is_list(body) do
    :quic_h3.send_data(pid, sid, IO.iodata_to_binary(body), true)
  end

  defp handle_response(data, sid, status, headers) do
    with_request(data, sid, fn ref, req ->
      case req.mode do
        :buffered ->
          {:keep_state, put_request(data, ref, %{req | status: status, headers: headers})}

        :streaming ->
          req = %{
            req
            | status: status,
              headers: headers,
              phase: :awaiting_body,
              idle_timer: schedule_idle_timeout(data, ref)
          }

          GenStateMachine.reply(req.from, {:ok, status, headers, ref, self()})
          {:keep_state, put_request(data, ref, req)}
      end
    end)
  end

  defp handle_data_chunk(data, sid, chunk) do
    with_request(data, sid, fn ref, req ->
      case req.mode do
        :buffered ->
          {:keep_state, put_request(data, ref, %{req | acc: [req.acc, chunk]})}

        :streaming ->
          {:keep_state, put_request(data, ref, push_streaming_chunk(data, req, ref, chunk))}
      end
    end)
  end

  defp handle_data_final(data, sid, chunk) do
    with_request(data, sid, fn ref, req ->
      case req.mode do
        :buffered ->
          finish_buffered(data, ref, sid, req, chunk, [])

        :streaming ->
          req = push_streaming_chunk(data, req, ref, chunk)
          finish_streaming(data, ref, sid, req)
      end
    end)
  end

  defp handle_trailers(data, sid, trailers) do
    with_request(data, sid, fn ref, req ->
      case req.mode do
        :buffered ->
          finish_buffered(data, ref, sid, req, <<>>, trailers)

        :streaming ->
          finish_streaming(data, ref, sid, %{req | trailers: trailers})
      end
    end)
  end

  defp handle_stream_reset(data, sid, code) do
    with_request(data, sid, fn ref, req ->
      cancel_idle_timer(req)
      err = H3StreamError.exception(stream_id: sid, code: code)
      reply_error(req, ref, err)
      data = cleanup_request(data, ref, sid, req.monitor)
      notify_pool(data, :stream_done)
      {:keep_state, data}
    end)
  end

  defp handle_stream_chunk(data, sid, chunk) do
    case Map.fetch(data.stream_to_ref, sid) do
      :error ->
        :keep_state_and_data

      {:ok, _ref} ->
        case :quic_h3.send_data(data.h3_conn, sid, chunk_to_binary(chunk), false) do
          :ok -> :keep_state_and_data
          {:error, reason} -> handle_send_error(data, sid, reason)
        end
    end
  end

  defp chunk_to_binary(chunk) when is_binary(chunk), do: chunk
  defp chunk_to_binary(chunk), do: IO.iodata_to_binary(chunk)

  defp handle_stream_end(data, sid) do
    case Map.fetch(data.stream_to_ref, sid) do
      :error ->
        :keep_state_and_data

      {:ok, ref} ->
        _ = :quic_h3.send_data(data.h3_conn, sid, <<>>, true)
        {:keep_state, %{data | stream_tasks: Map.delete(data.stream_tasks, ref)}}
    end
  end

  defp handle_stream_chunk_error(data, sid, reason) do
    with_request(data, sid, fn ref, req ->
      cancel_idle_timer(req)
      err = QUICTransportError.exception(code: 0, reason: {:stream_body_error, reason})
      reply_error(req, ref, err)
      _ = :quic_h3.cancel(data.h3_conn, sid)
      data = cleanup_request(data, ref, sid, req.monitor)
      notify_pool(data, :stream_done)
      {:keep_state, data}
    end)
  end

  defp handle_send_error(data, sid, reason) do
    with_request(data, sid, fn ref, req ->
      cancel_idle_timer(req)
      err = QUICTransportError.exception(code: 0, reason: {:send_failed, reason})
      reply_error(req, ref, err)
      _ = :quic_h3.cancel(data.h3_conn, sid)
      data = cleanup_request(data, ref, sid, req.monitor)
      notify_pool(data, :stream_done)
      {:keep_state, data}
    end)
  end

  defp with_request(data, sid, fun) do
    with {:ok, ref} <- Map.fetch(data.stream_to_ref, sid),
         {:ok, req} <- Map.fetch(data.requests, ref) do
      fun.(ref, req)
    else
      :error -> :keep_state_and_data
    end
  end

  defp put_request(data, ref, req), do: put_in(data, [Access.key!(:requests), ref], req)

  defp finish_buffered(data, ref, sid, req, last_chunk, trailers) do
    body = IO.iodata_to_binary([req.acc, last_chunk])

    response = %Response{
      status: req.status,
      headers: req.headers,
      body: body,
      trailers: trailers
    }

    GenStateMachine.reply(req.from, {:ok, response})
    data = cleanup_request(data, ref, sid, req.monitor)
    notify_pool(data, :stream_done)
    {:keep_state, data}
  end

  defp push_streaming_chunk(_data, %{demand_pid: nil} = req, _ref, <<>>), do: req

  defp push_streaming_chunk(_data, %{demand_pid: nil} = req, _ref, chunk) do
    %{req | pending_data: :queue.in(chunk, req.pending_data)}
  end

  defp push_streaming_chunk(data, %{demand_pid: pid} = req, ref, chunk) when pid != nil do
    if chunk == <<>> do
      req
    else
      send(pid, {:chunk, ref, chunk})
      timer = reschedule_idle_timeout(data, req.idle_timer, ref)
      %{req | demand_pid: nil, idle_timer: timer}
    end
  end

  defp finish_streaming(data, ref, _sid, req) do
    cancel_idle_timer(req)

    if req.demand_pid != nil do
      if req.trailers != [], do: send(req.demand_pid, {:trailers, ref, req.trailers})
      send(req.demand_pid, {:done, ref})
      data = cleanup_request(data, ref, req.stream_id, req.monitor)
      notify_pool(data, :stream_done)
      {:keep_state, data}
    else
      {:keep_state, put_request(data, ref, %{req | phase: :done, idle_timer: nil})}
    end
  end

  defp reply_error(%{mode: :streaming, phase: :awaiting_headers, from: from}, _ref, err) do
    GenStateMachine.reply(from, {:error, err})
  end

  defp reply_error(%{mode: :streaming, demand_pid: pid}, ref, err) when pid != nil do
    send(pid, {:error, ref, err})
  end

  defp reply_error(%{mode: :streaming}, _ref, _err), do: :ok

  defp reply_error(%{from: from}, _ref, err) do
    GenStateMachine.reply(from, {:error, err})
  end

  defp handle_demand(data, ref, consumer_pid) do
    case Map.fetch(data.requests, ref) do
      {:ok, %{mode: :streaming} = req} ->
        serve_demand(data, ref, req, consumer_pid)

      _ ->
        :keep_state_and_data
    end
  end

  defp serve_demand(data, ref, %{phase: :done} = req, consumer_pid) do
    case :queue.out(req.pending_data) do
      {{:value, chunk}, rest} ->
        send(consumer_pid, {:chunk, ref, chunk})
        {:keep_state, put_request(data, ref, %{req | pending_data: rest})}

      {:empty, _} ->
        serve_demand_empty(data, ref, req, consumer_pid)
    end
  end

  defp serve_demand(data, ref, req, consumer_pid) do
    case :queue.out(req.pending_data) do
      {{:value, chunk}, rest} ->
        send(consumer_pid, {:chunk, ref, chunk})
        timer = reschedule_idle_timeout(data, req.idle_timer, ref)
        {:keep_state, put_request(data, ref, %{req | pending_data: rest, idle_timer: timer})}

      {:empty, _} ->
        serve_demand_empty(data, ref, req, consumer_pid)
    end
  end

  defp serve_demand_empty(data, ref, %{phase: :done} = req, consumer_pid) do
    if req.trailers != [], do: send(consumer_pid, {:trailers, ref, req.trailers})
    send(consumer_pid, {:done, ref})
    data = cleanup_request(data, ref, req.stream_id, req.monitor)
    notify_pool(data, :stream_done)
    {:keep_state, data}
  end

  defp serve_demand_empty(data, ref, req, consumer_pid) do
    timer = reschedule_idle_timeout(data, req.idle_timer, ref)
    {:keep_state, put_request(data, ref, %{req | demand_pid: consumer_pid, idle_timer: timer})}
  end

  defp handle_cancel_stream(data, ref) do
    case Map.fetch(data.requests, ref) do
      {:ok, %{mode: :streaming} = req} ->
        cancel_idle_timer(req)
        _ = :quic_h3.cancel(data.h3_conn, req.stream_id)
        data = cleanup_request(data, ref, req.stream_id, req.monitor)
        notify_pool(data, :stream_done)
        {:keep_state, data}

      _ ->
        :keep_state_and_data
    end
  end

  defp handle_caller_down(data, ref, mon) do
    case Map.fetch(data.requests, ref) do
      {:ok, req} ->
        cancel_idle_timer(req)
        _ = :quic_h3.cancel(data.h3_conn, req.stream_id)
        data = cleanup_request(data, ref, req.stream_id, mon)
        notify_pool(data, :stream_done)
        {:keep_state, data}

      :error ->
        {:keep_state, %{data | monitors: Map.delete(data.monitors, mon)}}
    end
  end

  defp cleanup_request(data, ref, sid, monitor) do
    Process.demonitor(monitor, [:flush])
    stream_tasks = reap_stream_task(data.stream_tasks, ref, data.h3_conn, sid)

    %{
      data
      | requests: Map.delete(data.requests, ref),
        monitors: Map.delete(data.monitors, monitor),
        stream_to_ref: Map.delete(data.stream_to_ref, sid),
        stream_tasks: stream_tasks
    }
  end

  defp reap_stream_task(stream_tasks, ref, h3_conn, sid) do
    case Map.pop(stream_tasks, ref) do
      {nil, tasks} ->
        tasks

      {pid, tasks} ->
        _ = :quic_h3.cancel(h3_conn, sid)
        kill_stream_task(pid)
        tasks
    end
  end

  defp kill_stream_task(pid) do
    if Process.alive?(pid) do
      Process.unlink(pid)
      Process.exit(pid, :kill)
    end

    :ok
  end

  defp fail_all(data, error) do
    Enum.each(data.requests, fn {ref, req} ->
      Process.demonitor(req.monitor, [:flush])
      cancel_idle_timer(req)
      reply_error(req, ref, error)
    end)

    Enum.each(data.stream_tasks, fn {_ref, pid} -> kill_stream_task(pid) end)

    %{data | requests: %{}, monitors: %{}, stream_to_ref: %{}, stream_tasks: %{}}
  end

  defp fail_pending(data, error) do
    Enum.each(data.pending_during_connect, fn
      {:forward_request, from, _m, _p, _h, _b, _t} -> GenStateMachine.reply(from, {:error, error})
      {:forward_stream, from, _m, _p, _h, _b, _t} -> GenStateMachine.reply(from, {:error, error})
      _ -> :ok
    end)
  end

  defp notify_pool(%{pool_pid: nil}, _), do: :ok
  defp notify_pool(%{pool_pid: pid}, :stream_done), do: send(pid, {:stream_done, self()})

  defp notify_pool(%{pool_pid: pid}, :stream_open_failed),
    do: send(pid, {:stream_open_failed, self()})

  defp handle_idle_timeout(data, ref) do
    case Map.fetch(data.requests, ref) do
      {:ok, %{mode: :streaming} = req} ->
        if req.demand_pid, do: send(req.demand_pid, {:error, ref, :idle_timeout})
        _ = :quic_h3.cancel(data.h3_conn, req.stream_id)
        data = cleanup_request(data, ref, req.stream_id, req.monitor)
        notify_pool(data, :stream_done)
        {:keep_state, data}

      _ ->
        :keep_state_and_data
    end
  end

  defp schedule_idle_timeout(data, ref) do
    Process.send_after(self(), {:stream_idle_timeout, ref}, data.stream_idle_timeout)
  end

  defp reschedule_idle_timeout(data, nil, ref), do: schedule_idle_timeout(data, ref)

  defp reschedule_idle_timeout(data, timer, ref) do
    Process.cancel_timer(timer)
    schedule_idle_timeout(data, ref)
  end

  defp cancel_idle_timer(%{idle_timer: nil}), do: :ok
  defp cancel_idle_timer(%{idle_timer: timer}), do: Process.cancel_timer(timer)
  defp cancel_idle_timer(_), do: :ok
end
