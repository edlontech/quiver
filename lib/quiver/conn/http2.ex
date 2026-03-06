defmodule Quiver.Conn.HTTP2 do
  @moduledoc """
  HTTP/2 connection as a stateless data struct.

  Wraps a TLS transport with ALPN h2 negotiation. Multiplexes concurrent
  streams with HPACK compression and flow control.
  """

  @behaviour Quiver.Conn

  use TypedStruct

  alias Quiver.Conn.HTTP2.Frame
  alias Quiver.Error.CompressionError
  alias Quiver.Error.ConnectionClosed
  alias Quiver.Error.GoAway, as: GoAwayError
  alias Quiver.Error.InvalidScheme
  alias Quiver.Error.MaxConcurrentStreamsReached
  alias Quiver.Error.ProtocolViolation
  alias Quiver.Error.StreamClosed
  alias Quiver.Error.StreamReset
  alias Quiver.Transport

  @connection_preface "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"
  @default_recv_timeout 15_000
  @default_header_table_size 4096
  @default_initial_window_size 1_048_576
  @default_max_concurrent_streams 100
  @default_max_frame_size 16_384
  @rfc_default_window_size 65_535
  @window_update_ratio 0.5

  @error_no_error 0x0
  @error_refused_stream 0x7
  @error_cancel 0x8

  typedstruct do
    field(:transport, Transport.t(), enforce: true)
    field(:transport_mod, module(), enforce: true)
    field(:host, String.t(), enforce: true)
    field(:port, :inet.port_number(), enforce: true)
    field(:scheme, :http | :https, enforce: true)

    field(:state, :handshaking | :open | :goaway | :closed, default: :handshaking)
    field(:buffer, binary(), default: "")

    field(:encode_table, HPAX.Table.t())
    field(:decode_table, HPAX.Table.t())

    field(:streams, map(), default: %{})
    field(:next_stream_id, pos_integer(), default: 1)
    field(:ref_to_stream_id, map(), default: %{})

    field(:send_window, integer(), default: @default_initial_window_size)
    field(:recv_window, integer(), default: @default_initial_window_size)
    field(:recv_window_consumed, non_neg_integer(), default: 0)

    field(:server_settings, map(), default: %{})

    field(:client_settings, map(),
      default: %{
        header_table_size: @default_header_table_size,
        enable_push: 0,
        max_concurrent_streams: @default_max_concurrent_streams,
        initial_window_size: @default_initial_window_size,
        max_frame_size: @default_max_frame_size
      }
    )

    field(:settings_queue, :queue.queue(), default: :queue.new())

    field(:ping_queue, :queue.queue(), default: :queue.new())
    field(:recv_timeout, timeout(), default: @default_recv_timeout)

    field(:received_server_settings?, boolean(), default: false)
    field(:headers_being_processed, {pos_integer(), iolist(), boolean()} | nil, default: nil)
  end

  # -- Quiver.Conn callbacks --

  @impl true
  def connect(%URI{scheme: "https", host: host, port: port}, opts) do
    port = port || 443
    recv_timeout = Keyword.get(opts, :recv_timeout, @default_recv_timeout)

    ssl_opts = Keyword.put(opts, :alpn_advertised_protocols, ["h2"])

    case Transport.SSL.connect(host, port, ssl_opts) do
      {:ok, transport} ->
        case Transport.SSL.negotiated_protocol(transport) do
          "h2" ->
            conn = %__MODULE__{
              transport: transport,
              transport_mod: Transport.SSL,
              host: host,
              port: port,
              scheme: :https,
              recv_timeout: recv_timeout,
              encode_table: HPAX.new(@default_header_table_size),
              decode_table: HPAX.new(@default_header_table_size)
            }

            perform_handshake(conn)

          _other ->
            Transport.SSL.close(transport)
            {:error, ProtocolViolation.exception(message: "server did not negotiate h2 via ALPN")}
        end

      {:error, _} = error ->
        error
    end
  end

  def connect(%URI{scheme: "http"}, _opts) do
    {:error, ProtocolViolation.exception(message: "HTTP/2 requires TLS (h2c not supported)")}
  end

  def connect(%URI{scheme: scheme}, _opts) do
    {:error, InvalidScheme.exception(scheme: scheme)}
  end

  @impl true
  def open?(%__MODULE__{state: state}), do: state not in [:closed, :goaway]

  @impl true
  def close(%__MODULE__{state: :closed} = conn), do: {:ok, conn}

  def close(%__MODULE__{transport: transport, transport_mod: mod} = conn) do
    last_id = max_processed_stream_id(conn)
    goaway = Frame.encode_goaway(last_id, @error_no_error, "")
    _ = mod.send(transport, goaway)
    _ = mod.close(transport)
    {:ok, %{conn | state: :closed}}
  end

  @impl true
  def request(%__MODULE__{} = conn, method, path, headers, body) do
    case open_request(conn, method, path, headers, body) do
      {:ok, conn, ref} -> recv_response(conn, ref, [])
      {:error, _, _} = error -> error
    end
  end

  @impl true
  def open_request(%__MODULE__{state: state} = conn, _method, _path, _headers, _body)
      when state != :open do
    {:error, conn, ProtocolViolation.exception(message: "connection not open (state: #{state})")}
  end

  def open_request(%__MODULE__{} = conn, method, path, headers, body) do
    max = max_concurrent_streams(conn)

    if open_request_count(conn) >= max do
      {:error, conn, MaxConcurrentStreamsReached.exception(max: max)}
    else
      do_open_request(conn, method, path, headers, body)
    end
  end

  @impl true
  def stream(%__MODULE__{transport: %{socket: socket}} = conn, {tag, socket, data})
      when tag in [:tcp, :ssl] do
    buffer = conn.buffer <> data
    decode_frames(%{conn | buffer: ""}, buffer, [])
  end

  def stream(%__MODULE__{transport: %{socket: socket}} = conn, {closed_tag, socket})
      when closed_tag in [:tcp_closed, :ssl_closed] do
    fragments =
      for {_id, s} <- conn.streams,
          s.state in [:open, :half_closed_local],
          do: {:error, s.ref, ConnectionClosed.exception(message: "connection closed")}

    {:error, %{conn | state: :closed}, fragments}
  end

  def stream(%__MODULE__{transport: %{socket: socket}} = conn, {error_tag, socket, reason})
      when error_tag in [:tcp_error, :ssl_error] do
    {:error, %{conn | state: :closed}, reason}
  end

  def stream(%__MODULE__{}, _message), do: :unknown

  @impl true
  def cancel(%__MODULE__{} = conn, ref) do
    case Map.get(conn.ref_to_stream_id, ref) do
      nil ->
        {:error, conn, StreamClosed.exception(stream_id: 0)}

      stream_id ->
        frame = Frame.encode_rst_stream(stream_id, @error_cancel)

        case conn.transport_mod.send(conn.transport, frame) do
          {:ok, transport} ->
            conn = close_stream(%{conn | transport: transport}, stream_id)
            {:ok, conn}

          {:error, transport, reason} ->
            {:error, %{conn | transport: transport}, reason}
        end
    end
  end

  @impl true
  def open_request_count(%__MODULE__{streams: streams}) do
    Enum.count(streams, fn {_id, s} -> s.state in [:open, :half_closed_local] end)
  end

  @impl true
  def max_concurrent_streams(%__MODULE__{server_settings: settings}) do
    Map.get(settings, :max_concurrent_streams, @default_max_concurrent_streams)
  end

  # -- Handshake --

  defp perform_handshake(conn) do
    client_settings = settings_to_pairs(conn.client_settings)

    {window_frame, recv_window} =
      case conn.client_settings.initial_window_size - @rfc_default_window_size do
        n when n > 0 -> {Frame.encode_window_update(0, n), @rfc_default_window_size + n}
        _ -> {[], @rfc_default_window_size}
      end

    preface = [
      @connection_preface,
      Frame.encode_settings(client_settings),
      window_frame
    ]

    case conn.transport_mod.send(conn.transport, preface) do
      {:ok, transport} ->
        conn = %{
          conn
          | transport: transport,
            recv_window: recv_window,
            settings_queue: :queue.in(:initial, conn.settings_queue)
        }

        handshake_loop(conn)

      {:error, _transport, reason} ->
        {:error, reason}
    end
  end

  defp handshake_loop(conn) do
    case {conn.received_server_settings?, :queue.is_empty(conn.settings_queue)} do
      {true, true} ->
        {:ok, %{conn | state: :open}}

      _ ->
        recv_handshake_frame(conn)
    end
  end

  defp recv_handshake_frame(conn) do
    case conn.transport_mod.recv(conn.transport, 0, conn.recv_timeout) do
      {:ok, transport, data} ->
        buffer = conn.buffer <> data

        case decode_frames(%{conn | transport: transport, buffer: ""}, buffer, []) do
          {:ok, conn, _fragments} -> handshake_loop(conn)
          {:error, _conn, reason} -> {:error, reason}
        end

      {:error, _transport, reason} ->
        {:error, reason}
    end
  end

  # -- Sending requests --

  defp do_open_request(conn, method, path, headers, body) do
    stream_id = conn.next_stream_id
    ref = make_ref()

    pseudo_headers = [
      {":method", to_string(method) |> String.upcase()},
      {":path", path},
      {":scheme", to_string(conn.scheme)},
      {":authority", authority(conn)}
    ]

    all_headers = pseudo_headers ++ Quiver.Utils.normalize_headers(headers)
    {encoded_headers, encode_table} = HPAX.encode(:store, all_headers, conn.encode_table)
    header_block = IO.iodata_to_binary(encoded_headers)

    end_stream? = body == nil or body == "" or body == []
    frames = [Frame.encode_headers(stream_id, header_block, true, end_stream?)]

    frames =
      if end_stream? do
        frames
      else
        body_binary = IO.iodata_to_binary(body)
        frames ++ [Frame.encode_data(stream_id, body_binary, true)]
      end

    case conn.transport_mod.send(conn.transport, frames) do
      {:ok, transport} ->
        stream_state = if end_stream?, do: :half_closed_local, else: :open

        stream = %{
          id: stream_id,
          ref: ref,
          state: stream_state,
          send_window: server_initial_window_size(conn),
          recv_window: conn.client_settings.initial_window_size,
          recv_window_consumed: 0,
          received_headers?: false
        }

        conn = %{
          conn
          | transport: transport,
            encode_table: encode_table,
            next_stream_id: stream_id + 2,
            streams: Map.put(conn.streams, stream_id, stream),
            ref_to_stream_id: Map.put(conn.ref_to_stream_id, ref, stream_id)
        }

        {:ok, conn, ref}

      {:error, transport, reason} ->
        {:error, %{conn | transport: transport}, reason}
    end
  end

  # -- Blocking response collection --

  defp recv_response(conn, ref, acc) do
    case conn.transport_mod.recv(conn.transport, 0, conn.recv_timeout) do
      {:ok, transport, data} ->
        buffer = conn.buffer <> data
        process_recv_data(conn, transport, buffer, ref, acc)

      {:error, transport, reason} ->
        {:error, %{conn | transport: transport, state: :closed}, reason}
    end
  end

  defp process_recv_data(conn, transport, buffer, ref, acc) do
    case decode_frames(%{conn | transport: transport, buffer: ""}, buffer, []) do
      {:ok, conn, fragments} ->
        all = [fragments | acc]

        if Enum.any?(fragments, &match?({:done, ^ref}, &1)) do
          response = assemble_response(List.flatten(:lists.reverse(all)), ref)
          {:ok, conn, response}
        else
          recv_response(conn, ref, all)
        end

      {:error, conn, reason} ->
        {:error, conn, reason}
    end
  end

  defp assemble_response(fragments, ref) do
    status =
      Enum.find_value(fragments, fn
        {:status, ^ref, s} -> s
        _ -> nil
      end)

    headers =
      fragments
      |> Enum.flat_map(fn
        {:headers, ^ref, h} -> h
        _ -> []
      end)

    data_chunks = for {:data, ^ref, d} <- fragments, d != "", do: d

    body =
      case data_chunks do
        [] -> nil
        chunks -> IO.iodata_to_binary(chunks)
      end

    %Quiver.Response{status: status, headers: headers, body: body}
  end

  # -- Frame decoding loop --

  defp decode_frames(conn, buffer, acc) do
    case Frame.decode(buffer) do
      {:ok, frame, rest} ->
        case handle_frame(conn, frame) do
          {:ok, conn, []} ->
            decode_frames(conn, rest, acc)

          {:ok, conn, new_fragments} ->
            decode_frames(conn, rest, [new_fragments | acc])

          {:error, conn, reason} ->
            {:error, conn, reason}
        end

      :more ->
        case flush_recv_windows(conn) do
          {:ok, conn} ->
            {:ok, %{conn | buffer: buffer}, List.flatten(:lists.reverse(acc))}

          {:error, conn, reason} ->
            {:error, conn, reason}
        end

      {:error, reason} ->
        {:error, conn, ProtocolViolation.exception(message: "frame decode error: #{reason}")}
    end
  end

  # -- Frame handlers --

  defp handle_frame(conn, {:data, 0, _flags, _payload}) do
    send_goaway_and_close(conn, 0x1, "DATA frame on stream 0")
  end

  defp handle_frame(conn, {:data, stream_id, flags, payload}) do
    data_size = byte_size(payload)
    conn = consume_recv_windows(conn, stream_id, data_size)

    case Map.get(conn.streams, stream_id) do
      nil ->
        {:ok, conn, []}

      stream ->
        end_stream? = Frame.flag_set?(flags, 0x1)

        fragments = [{:data, stream.ref, payload}]

        {conn, fragments} =
          if end_stream? do
            conn = transition_stream(conn, stream_id, :half_closed_remote)
            {conn, fragments ++ [{:done, stream.ref}]}
          else
            {conn, fragments}
          end

        {:ok, conn, fragments}
    end
  end

  defp handle_frame(conn, {:headers, 0, _flags, _header_block, _priority}) do
    send_goaway_and_close(conn, 0x1, "HEADERS frame on stream 0")
  end

  defp handle_frame(conn, {:headers, stream_id, flags, header_block, _priority}) do
    end_headers? = Frame.flag_set?(flags, 0x4)
    end_stream? = Frame.flag_set?(flags, 0x1)

    if end_headers? do
      decode_header_block(conn, stream_id, header_block, end_stream?)
    else
      conn = %{conn | headers_being_processed: {stream_id, [header_block], end_stream?}}
      {:ok, conn, []}
    end
  end

  defp handle_frame(conn, {:continuation, stream_id, flags, fragment}) do
    case conn.headers_being_processed do
      {^stream_id, blocks, end_stream?} ->
        blocks = [blocks, fragment]

        if Frame.flag_set?(flags, 0x4) do
          full_block = IO.iodata_to_binary(blocks)
          conn = %{conn | headers_being_processed: nil}
          decode_header_block(conn, stream_id, full_block, end_stream?)
        else
          conn = %{conn | headers_being_processed: {stream_id, blocks, end_stream?}}
          {:ok, conn, []}
        end

      _ ->
        {:error, conn, ProtocolViolation.exception(message: "unexpected CONTINUATION")}
    end
  end

  defp handle_frame(conn, {:settings, :ack, []}) do
    case :queue.out(conn.settings_queue) do
      {{:value, _}, queue} ->
        {:ok, %{conn | settings_queue: queue}, []}

      {:empty, _} ->
        {:ok, conn, []}
    end
  end

  defp handle_frame(conn, {:settings, :no_ack, settings}) do
    old_initial =
      Map.get(conn.server_settings, :initial_window_size, @default_initial_window_size)

    server_settings =
      Enum.reduce(settings, conn.server_settings, fn {key, value}, acc ->
        Map.put(acc, key, value)
      end)

    new_initial = Map.get(server_settings, :initial_window_size, @default_initial_window_size)
    delta = new_initial - old_initial

    ack = Frame.encode_settings_ack()

    case conn.transport_mod.send(conn.transport, ack) do
      {:ok, transport} ->
        conn = %{
          conn
          | transport: transport,
            server_settings: server_settings,
            received_server_settings?: true
        }

        conn = adjust_stream_windows(conn, delta)
        {:ok, conn, []}

      {:error, transport, reason} ->
        {:error, %{conn | transport: transport}, reason}
    end
  end

  @max_window_size 0x7FFFFFFF

  defp handle_frame(conn, {:window_update, 0, increment}) do
    new_window = min(conn.send_window + increment, @max_window_size)
    {:ok, %{conn | send_window: new_window}, []}
  end

  defp handle_frame(conn, {:window_update, stream_id, increment}) do
    case Map.get(conn.streams, stream_id) do
      nil ->
        {:ok, conn, []}

      stream ->
        new_window = min(stream.send_window + increment, @max_window_size)
        stream = %{stream | send_window: new_window}
        {:ok, %{conn | streams: Map.put(conn.streams, stream_id, stream)}, []}
    end
  end

  defp handle_frame(conn, {:ping, :ack, opaque_data}) do
    case :queue.out(conn.ping_queue) do
      {{:value, {ref, ^opaque_data}}, queue} ->
        {:ok, %{conn | ping_queue: queue}, [{:pong, ref}]}

      _ ->
        {:ok, conn, []}
    end
  end

  defp handle_frame(conn, {:ping, :no_ack, opaque_data}) do
    pong = Frame.encode_pong(opaque_data)

    case conn.transport_mod.send(conn.transport, pong) do
      {:ok, transport} -> {:ok, %{conn | transport: transport}, []}
      {:error, transport, reason} -> {:error, %{conn | transport: transport}, reason}
    end
  end

  defp handle_frame(conn, {:goaway, last_stream_id, error_code, debug_data}) do
    error =
      GoAwayError.exception(
        last_stream_id: last_stream_id,
        error_code: error_code,
        debug_data: debug_data
      )

    fragments =
      for {id, stream} <- conn.streams,
          id > last_stream_id,
          stream.state in [:open, :half_closed_local],
          do: {:error, stream.ref, error}

    conn =
      Enum.reduce(conn.streams, conn, fn {id, _stream}, acc ->
        if id > last_stream_id, do: close_stream(acc, id), else: acc
      end)

    {:ok, %{conn | state: :goaway}, fragments}
  end

  defp handle_frame(conn, {:rst_stream, 0, _error_code}) do
    send_goaway_and_close(conn, 0x1, "RST_STREAM frame on stream 0")
  end

  defp handle_frame(conn, {:rst_stream, stream_id, error_code}) do
    case Map.get(conn.streams, stream_id) do
      nil ->
        {:ok, conn, []}

      stream ->
        error = StreamReset.exception(stream_id: stream_id, error_code: error_code)
        conn = close_stream(conn, stream_id)
        {:ok, conn, [{:error, stream.ref, error}]}
    end
  end

  defp handle_frame(conn, {:push_promise, _stream_id, _flags, promised_id, _header_block}) do
    rst = Frame.encode_rst_stream(promised_id, @error_refused_stream)

    case conn.transport_mod.send(conn.transport, rst) do
      {:ok, transport} -> {:ok, %{conn | transport: transport}, []}
      {:error, transport, reason} -> {:error, %{conn | transport: transport}, reason}
    end
  end

  defp handle_frame(conn, {:priority, _stream_id, _exclusive, _dep, _weight}) do
    {:ok, conn, []}
  end

  defp handle_frame(conn, {:unknown, _type, _stream_id, _flags, _payload}) do
    {:ok, conn, []}
  end

  # -- Header block decoding --

  defp decode_header_block(conn, stream_id, header_block, end_stream?) do
    case HPAX.decode(header_block, conn.decode_table) do
      {:ok, headers, decode_table} ->
        conn = %{conn | decode_table: decode_table}
        process_decoded_headers(conn, stream_id, headers, end_stream?)

      {:error, reason} ->
        {:error, conn,
         CompressionError.exception(message: "HPACK decode error: #{inspect(reason)}")}
    end
  end

  defp process_decoded_headers(conn, stream_id, decoded_headers, end_stream?) do
    case Map.get(conn.streams, stream_id) do
      nil ->
        {:ok, conn, []}

      stream ->
        {pseudo, regular} =
          Enum.split_with(decoded_headers, fn {name, _} -> String.starts_with?(name, ":") end)

        fragments = build_header_fragments(stream.ref, pseudo, regular)

        {conn, fragments} =
          if end_stream? do
            conn = transition_stream(conn, stream_id, :half_closed_remote)
            {conn, fragments ++ [{:done, stream.ref}]}
          else
            stream = %{stream | received_headers?: true}
            conn = %{conn | streams: Map.put(conn.streams, stream_id, stream)}
            {conn, fragments}
          end

        {:ok, conn, fragments}
    end
  end

  defp build_header_fragments(ref, pseudo_headers, regular_headers) do
    status_fragment =
      case List.keyfind(pseudo_headers, ":status", 0) do
        {":status", status_str} -> [{:status, ref, String.to_integer(status_str)}]
        nil -> []
      end

    header_fragment =
      if regular_headers != [] do
        [{:headers, ref, regular_headers}]
      else
        []
      end

    status_fragment ++ header_fragment
  end

  # -- Flow control --

  defp consume_recv_windows(conn, _stream_id, 0), do: conn

  defp consume_recv_windows(conn, stream_id, data_size) do
    conn = %{
      conn
      | recv_window: conn.recv_window - data_size,
        recv_window_consumed: conn.recv_window_consumed + data_size
    }

    case Map.get(conn.streams, stream_id) do
      nil ->
        conn

      stream ->
        put_in(conn.streams[stream_id], %{
          stream
          | recv_window: stream.recv_window - data_size,
            recv_window_consumed: stream.recv_window_consumed + data_size
        })
    end
  end

  defp flush_recv_windows(conn) do
    initial = conn.client_settings.initial_window_size
    threshold = trunc(initial * @window_update_ratio)

    frames = []

    {conn, frames} =
      if conn.recv_window_consumed >= threshold do
        increment = conn.recv_window_consumed
        conn = %{conn | recv_window: conn.recv_window + increment, recv_window_consumed: 0}
        {conn, [Frame.encode_window_update(0, increment) | frames]}
      else
        {conn, frames}
      end

    {conn, frames} =
      Enum.reduce(conn.streams, {conn, frames}, fn {stream_id, stream}, {conn, frames} ->
        if stream.recv_window_consumed >= threshold do
          increment = stream.recv_window_consumed

          stream = %{
            stream
            | recv_window: stream.recv_window + increment,
              recv_window_consumed: 0
          }

          conn = put_in(conn.streams[stream_id], stream)
          {conn, [Frame.encode_window_update(stream_id, increment) | frames]}
        else
          {conn, frames}
        end
      end)

    case frames do
      [] ->
        {:ok, conn}

      frames ->
        case conn.transport_mod.send(conn.transport, frames) do
          {:ok, transport} ->
            {:ok, %{conn | transport: transport}}

          {:error, transport, reason} ->
            {:error, %{conn | transport: transport, state: :closed}, reason}
        end
    end
  end

  defp send_goaway_and_close(conn, error_code, debug) do
    last_id = max_processed_stream_id(conn)
    goaway = Frame.encode_goaway(last_id, error_code, debug)
    _ = conn.transport_mod.send(conn.transport, goaway)
    _ = conn.transport_mod.close(conn.transport)

    error = ProtocolViolation.exception(message: debug)

    fragments =
      for {_id, s} <- conn.streams,
          s.state in [:open, :half_closed_local],
          do: {:error, s.ref, error}

    {:error, %{conn | state: :closed}, fragments}
  end

  defp adjust_stream_windows(conn, 0), do: conn

  defp adjust_stream_windows(conn, delta) do
    streams =
      Map.new(conn.streams, fn {id, stream} ->
        {id, %{stream | send_window: stream.send_window + delta}}
      end)

    %{conn | streams: streams}
  end

  # -- Stream state management --

  defp transition_stream(conn, stream_id, new_remote_state) do
    case Map.get(conn.streams, stream_id) do
      nil ->
        conn

      %{state: :open} when new_remote_state == :half_closed_remote ->
        put_in(conn.streams[stream_id].state, :half_closed_remote)

      %{state: :half_closed_local} when new_remote_state == :half_closed_remote ->
        close_stream(conn, stream_id)

      _ ->
        conn
    end
  end

  defp close_stream(conn, stream_id) do
    case Map.get(conn.streams, stream_id) do
      nil ->
        conn

      stream ->
        %{
          conn
          | streams: Map.delete(conn.streams, stream_id),
            ref_to_stream_id: Map.delete(conn.ref_to_stream_id, stream.ref)
        }
    end
  end

  defp max_processed_stream_id(%__MODULE__{streams: streams}) when map_size(streams) == 0, do: 0

  defp max_processed_stream_id(%__MODULE__{streams: streams}) do
    streams |> Map.keys() |> Enum.max()
  end

  # -- Helpers --

  defp authority(%__MODULE__{host: host, port: 443}), do: host
  defp authority(%__MODULE__{host: host, port: port}), do: "#{host}:#{port}"

  defp server_initial_window_size(%__MODULE__{server_settings: settings}) do
    Map.get(settings, :initial_window_size, @default_initial_window_size)
  end

  defp settings_to_pairs(settings) do
    Enum.map(settings, fn {key, value} ->
      {Frame.settings_atom_to_id(key), value}
    end)
  end
end
