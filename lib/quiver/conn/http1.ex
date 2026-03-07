defmodule Quiver.Conn.HTTP1 do
  @moduledoc """
  HTTP/1.1 connection as a stateless data struct.

  Wraps a TCP or SSL transport. Sequential request-response
  with keep-alive support.
  """

  @behaviour Quiver.Conn

  use TypedStruct

  alias Quiver.Conn.HTTP1.Parse
  alias Quiver.Conn.HTTP1.Request, as: RequestEncoder
  alias Quiver.Error.ConnectionClosed
  alias Quiver.Error.InvalidScheme
  alias Quiver.Error.ProtocolViolation
  alias Quiver.Transport

  @default_recv_timeout 15_000

  typedstruct do
    field(:transport, Transport.t(), enforce: true)
    field(:transport_mod, module(), enforce: true)
    field(:host, String.t(), enforce: true)
    field(:port, :inet.port_number(), enforce: true)
    field(:scheme, :http | :https, enforce: true)
    field(:buffer, binary(), default: "")
    field(:parse_state, Parse.parse_state(), default: :idle)
    field(:keep_alive, boolean(), default: true)
    field(:request_state, :idle | :in_flight, default: :idle)
    field(:closed, boolean(), default: false)
    field(:recv_timeout, timeout(), default: @default_recv_timeout)
    field(:request_ref, reference() | nil, default: nil)
  end

  @impl true
  def connect(%URI{scheme: scheme, host: host, port: port}, opts)
      when scheme in ["http", "https"] do
    {transport_mod, scheme_atom} = transport_for_scheme(scheme)
    port = port || default_port(scheme)

    recv_timeout = Keyword.get(opts, :recv_timeout, @default_recv_timeout)

    case transport_mod.connect(host, port, opts) do
      {:ok, transport} ->
        {:ok,
         %__MODULE__{
           transport: transport,
           transport_mod: transport_mod,
           host: host,
           port: port,
           scheme: scheme_atom,
           recv_timeout: recv_timeout
         }}

      {:error, _} = error ->
        error
    end
  end

  def connect(%URI{scheme: scheme}, _opts) do
    {:error, InvalidScheme.exception(scheme: scheme)}
  end

  @doc """
  Returns whether the connection may accept another request.

  Does not probe the underlying transport -- a TCP reset that occurred
  since the last send/recv will not be detected here. Dead connections
  are discovered on the next request attempt.
  """
  @impl true
  def open?(%__MODULE__{closed: true}), do: false
  def open?(%__MODULE__{keep_alive: false}), do: false
  def open?(%__MODULE__{}), do: true

  @impl true
  def close(%__MODULE__{transport: transport, transport_mod: mod} = conn) do
    {:ok, _transport} = mod.close(transport)
    {:ok, %{conn | closed: true}}
  end

  @impl true
  def request(%__MODULE__{request_state: :in_flight} = conn, _method, _path, _headers, _body) do
    {:error, %{conn | keep_alive: false},
     ProtocolViolation.exception(message: "request already in flight")}
  end

  def request(%__MODULE__{} = conn, method, path, headers, body) do
    ref = make_ref()
    headers = add_host_header(headers, conn.host, conn.port, conn.scheme)
    encoded = RequestEncoder.encode(method, path, headers, body)

    case conn.transport_mod.send(conn.transport, encoded) do
      {:ok, transport} ->
        conn = %{
          conn
          | transport: transport,
            request_state: :in_flight,
            parse_state: :status,
            buffer: "",
            request_ref: ref
        }

        recv_loop(conn, [])

      {:error, transport, reason} ->
        {:error, %{conn | transport: transport, keep_alive: false}, reason}
    end
  end

  @impl true
  def open_request(%__MODULE__{request_state: :in_flight} = conn, _method, _path, _headers, _body) do
    {:error, %{conn | keep_alive: false},
     ProtocolViolation.exception(message: "request already in flight")}
  end

  def open_request(%__MODULE__{} = conn, method, path, headers, body) do
    ref = make_ref()
    headers = add_host_header(headers, conn.host, conn.port, conn.scheme)
    encoded = RequestEncoder.encode(method, path, headers, body)

    case conn.transport_mod.send(conn.transport, encoded) do
      {:ok, transport} ->
        conn = %{
          conn
          | transport: transport,
            request_state: :in_flight,
            parse_state: :status,
            buffer: "",
            request_ref: ref
        }

        {:ok, conn, ref}

      {:error, transport, reason} ->
        {:error, %{conn | transport: transport, keep_alive: false}, reason}
    end
  end

  @doc """
  Receives response status and headers after a request has been sent via `open_request/5`.

  Returns any body data that arrived alongside the headers in `initial_body_chunks`.
  Call `recv_body_chunk/1` to continue receiving the body.
  """
  @spec recv_response_headers(t()) ::
          {:ok, t(), non_neg_integer(), [{String.t(), String.t()}], [binary()]}
          | {:error, t(), term()}
  def recv_response_headers(%__MODULE__{request_state: :in_flight} = conn) do
    recv_headers_loop(conn, [])
  end

  @doc """
  Receives the next chunk of response body data.

  Returns `{:ok, conn, chunk}` with binary data, `{:done, conn}` when the body is
  complete, or `{:error, conn, reason}` on failure.
  """
  @spec recv_body_chunk(t()) :: {:ok, t(), binary()} | {:done, t()} | {:error, t(), term()}
  def recv_body_chunk(%__MODULE__{request_state: :idle} = conn), do: {:done, conn}

  def recv_body_chunk(%__MODULE__{} = conn) do
    if conn.buffer != "" do
      parse_body(conn, conn.buffer)
    else
      case conn.transport_mod.recv(conn.transport, 0, conn.recv_timeout) do
        {:ok, transport, data} ->
          parse_body(%{conn | transport: transport}, data)

        {:error, transport, %ConnectionClosed{}}
        when conn.parse_state == :body_until_close ->
          {:done, %{conn | transport: transport, keep_alive: false, request_state: :idle}}

        {:error, transport, reason} ->
          {:error, %{conn | transport: transport, keep_alive: false, request_state: :idle},
           reason}
      end
    end
  end

  @impl true
  def cancel(%__MODULE__{} = conn, _ref) do
    close(conn)
  end

  @impl true
  def open_request_count(%__MODULE__{request_state: :in_flight}), do: 1
  def open_request_count(%__MODULE__{}), do: 0

  @impl true
  def max_concurrent_streams(%__MODULE__{}), do: 1

  @impl true
  def stream(%__MODULE__{transport: %{socket: socket}} = conn, {tag, socket, data})
      when tag in [:tcp, :ssl] do
    full_data = conn.buffer <> data
    stream_parse(conn, full_data, [])
  end

  def stream(%__MODULE__{transport: %{socket: socket}} = conn, {closed_tag, socket})
      when closed_tag in [:tcp_closed, :ssl_closed] do
    ref = conn.request_ref

    if conn.parse_state == :body_until_close do
      conn = %{conn | keep_alive: false, request_state: :idle, parse_state: :idle}
      {:ok, conn, [{:done, ref}]}
    else
      {:error, %{conn | keep_alive: false, request_state: :idle},
       ConnectionClosed.exception(message: "connection closed")}
    end
  end

  def stream(%__MODULE__{transport: %{socket: socket}} = conn, {error_tag, socket, reason})
      when error_tag in [:tcp_error, :ssl_error] do
    {:error, %{conn | keep_alive: false, request_state: :idle}, reason}
  end

  def stream(%__MODULE__{}, _message) do
    :unknown
  end

  defp stream_parse(conn, data, acc) do
    case Parse.parse(data, conn.parse_state) do
      {:error, reason} ->
        {:error, %{conn | keep_alive: false, request_state: :idle}, reason}

      {[], new_state, rest} ->
        conn = %{conn | parse_state: new_state, buffer: rest}
        {:ok, conn, acc}

      {fragments, new_state, rest} ->
        conn = %{conn | parse_state: new_state, buffer: rest}
        conn = update_keep_alive(conn, fragments)
        tagged = tag_fragments(fragments, conn.request_ref)
        all = acc ++ tagged
        stream_parse_continue(conn, rest, all, response_complete?(fragments))
    end
  end

  defp stream_parse_continue(conn, _rest, all, true) do
    {:ok, %{conn | request_state: :idle}, all}
  end

  defp stream_parse_continue(conn, rest, all, false) when rest != "" do
    stream_parse(conn, rest, all)
  end

  defp stream_parse_continue(conn, _rest, all, false) do
    {:ok, conn, all}
  end

  defp recv_loop(conn, acc_fragments) do
    if conn.buffer != "" do
      parse_and_continue(conn, conn.buffer, acc_fragments)
    else
      case conn.transport_mod.recv(conn.transport, 0, conn.recv_timeout) do
        {:ok, transport, data} ->
          parse_and_continue(%{conn | transport: transport}, data, acc_fragments)

        {:error, transport, %ConnectionClosed{}}
        when conn.parse_state == :body_until_close ->
          conn = %{conn | transport: transport, keep_alive: false, request_state: :idle}
          all_fragments = acc_fragments ++ [{:done, conn.request_ref}]
          response = assemble_response(all_fragments)
          {:ok, conn, response}

        {:error, transport, reason} ->
          {:error, %{conn | transport: transport, keep_alive: false, request_state: :idle},
           reason}
      end
    end
  end

  defp parse_and_continue(conn, data, acc_fragments) do
    case Parse.parse(data, conn.parse_state) do
      {:error, reason} ->
        {:error, %{conn | keep_alive: false, request_state: :idle}, reason}

      {fragments, new_state, rest} ->
        conn = %{conn | parse_state: new_state, buffer: rest}
        conn = update_keep_alive(conn, fragments)
        tagged = tag_fragments(fragments, conn.request_ref)
        all_fragments = acc_fragments ++ tagged

        if response_complete?(fragments) do
          response = assemble_response(all_fragments)
          {:ok, %{conn | request_state: :idle}, response}
        else
          recv_loop(conn, all_fragments)
        end
    end
  end

  defp recv_headers_loop(conn, acc) do
    if conn.buffer != "" do
      parse_for_headers(conn, conn.buffer, acc)
    else
      case conn.transport_mod.recv(conn.transport, 0, conn.recv_timeout) do
        {:ok, transport, data} ->
          parse_for_headers(%{conn | transport: transport}, data, acc)

        {:error, transport, reason} ->
          {:error, %{conn | transport: transport, keep_alive: false, request_state: :idle},
           reason}
      end
    end
  end

  defp parse_for_headers(conn, data, acc) do
    case Parse.parse(data, conn.parse_state) do
      {:error, reason} ->
        {:error, %{conn | keep_alive: false, request_state: :idle}, reason}

      {fragments, new_state, rest} ->
        conn = %{conn | parse_state: new_state, buffer: rest}
        conn = update_keep_alive(conn, fragments)
        all = acc ++ fragments
        maybe_extract_headers(conn, fragments, all)
    end
  end

  defp maybe_extract_headers(conn, fragments, all) do
    if Enum.any?(fragments, &match?({:headers, _}, &1)) do
      {status, headers, body_chunks} = split_header_info(all)
      conn = if :done in all, do: %{conn | request_state: :idle}, else: conn
      {:ok, conn, status, headers, body_chunks}
    else
      recv_headers_loop(conn, all)
    end
  end

  defp split_header_info(fragments) do
    status =
      Enum.find_value(fragments, fn
        {:status, s} -> s
        _ -> nil
      end)

    headers =
      Enum.find_value(fragments, fn
        {:headers, h} -> h
        _ -> nil
      end) || []

    body_chunks = for {:data, d} <- fragments, d != "", do: d

    {status, headers, body_chunks}
  end

  defp parse_body(conn, data) do
    case Parse.parse(data, conn.parse_state) do
      {:error, reason} ->
        {:error, %{conn | keep_alive: false, request_state: :idle}, reason}

      {fragments, new_state, rest} ->
        conn = %{conn | parse_state: new_state, buffer: rest}
        body_chunks = for {:data, d} <- fragments, d != "", do: d
        done? = :done in fragments
        conn = if done?, do: %{conn | request_state: :idle}, else: conn

        case {body_chunks, done?} do
          {[], true} -> {:done, conn}
          {[], false} -> recv_body_chunk(conn)
          {chunks, _} -> {:ok, conn, IO.iodata_to_binary(chunks)}
        end
    end
  end

  defp tag_fragments(fragments, ref) do
    Enum.map(fragments, fn
      {:status, s} -> {:status, ref, s}
      {:headers, h} -> {:headers, ref, h}
      {:trailers, t} -> {:trailers, ref, t}
      {:data, d} -> {:data, ref, d}
      :done -> {:done, ref}
    end)
  end

  defp add_host_header(headers, host, port, scheme) do
    if List.keymember?(headers, "host", 0) do
      headers
    else
      host_value =
        case {scheme, port} do
          {:http, 80} -> host
          {:https, 443} -> host
          {_, port} -> "#{host}:#{port}"
        end

      [{"host", host_value} | headers]
    end
  end

  defp response_complete?(fragments), do: :done in fragments

  defp update_keep_alive(conn, fragments) do
    with {:headers, headers} <- Enum.find(fragments, &match?({:headers, _}, &1)),
         {"connection", value} <- List.keyfind(headers, "connection", 0),
         true <- String.downcase(value) == "close" do
      %{conn | keep_alive: false}
    else
      _ -> conn
    end
  end

  defp assemble_response(fragments) do
    status =
      Enum.find_value(fragments, fn
        {:status, _ref, s} -> s
        _ -> nil
      end)

    headers =
      Enum.find_value(fragments, fn
        {:headers, _ref, h} -> h
        _ -> nil
      end) || []

    trailers =
      Enum.find_value(fragments, fn
        {:trailers, _ref, t} -> t
        _ -> nil
      end) || []

    data_chunks = for {:data, _ref, d} <- fragments, d != "", do: d

    body =
      case data_chunks do
        [] -> nil
        chunks -> IO.iodata_to_binary(chunks)
      end

    %Quiver.Response{status: status, headers: headers, body: body, trailers: trailers}
  end

  defp transport_for_scheme("http"), do: {Quiver.Transport.TCP, :http}
  defp transport_for_scheme("https"), do: {Quiver.Transport.SSL, :https}

  defp default_port("http"), do: 80
  defp default_port("https"), do: 443
end
