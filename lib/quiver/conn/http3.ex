defmodule Quiver.Conn.HTTP3 do
  @moduledoc """
  HTTP/3 connection wrapper.

  Holds a `quic_h3` pid plus per-stream tracking. Implements `Quiver.Conn`
  by delegating to `:quic_h3` calls. Not a process itself; the calling
  process is the H3 connection's owner.

  Used standalone (synchronous connect) or by `Quiver.Pool.HTTP3.Connection`
  (which manages an async-connect worker and only uses `open_request`,
  `stream`, `cancel`, `close`).
  """

  @behaviour Quiver.Conn

  @dialyzer {:nowarn_function, connect: 2, query_peer_max_streams: 2}

  alias Quiver.Error.H3StreamError
  alias Quiver.Error.QUICHandshakeFailed
  alias Quiver.Error.QUICTransportError
  alias Quiver.Response

  @forbidden_headers ~w(connection keep-alive transfer-encoding upgrade proxy-connection)

  defstruct [
    :h3_conn,
    :host,
    :port,
    :scheme,
    :peer_max_streams,
    :recv_timeout,
    ref_to_stream_id: %{},
    stream_id_to_ref: %{}
  ]

  @type t :: %__MODULE__{
          h3_conn: pid() | nil,
          host: String.t(),
          port: :inet.port_number(),
          scheme: :https,
          peer_max_streams: non_neg_integer(),
          recv_timeout: timeout(),
          ref_to_stream_id: %{reference() => non_neg_integer()},
          stream_id_to_ref: %{non_neg_integer() => reference()}
        }

  @impl Quiver.Conn
  def connect(uri, opts \\ [])

  def connect(%URI{scheme: "https"} = uri, opts) do
    host = uri.host
    port = uri.port || 443
    timeout = Keyword.get(opts, :connect_timeout, 5_000)

    h3_opts =
      opts
      |> build_h3_opts()
      |> Map.put(:sync, true)
      |> Map.put(:connect_timeout, timeout)

    case :quic_h3.connect(host, port, h3_opts) do
      {:ok, h3_conn} ->
        {:ok,
         %__MODULE__{
           h3_conn: h3_conn,
           host: host,
           port: port,
           scheme: :https,
           peer_max_streams:
             query_peer_max_streams(h3_conn, Keyword.get(opts, :initial_max_streams, 100)),
           recv_timeout: Keyword.get(opts, :recv_timeout, 15_000)
         }}

      {:error, reason} ->
        {:error,
         QUICHandshakeFailed.exception(
           origin: {:https, host, port},
           reason: reason
         )}
    end
  end

  def connect(%URI{scheme: scheme} = uri, _opts) do
    {:error,
     QUICHandshakeFailed.exception(
       origin: {scheme |> to_string() |> String.to_atom(), uri.host, uri.port},
       reason: {:invalid_scheme, scheme}
     )}
  end

  @impl Quiver.Conn
  def open?(%__MODULE__{h3_conn: pid}) when is_pid(pid), do: Process.alive?(pid)
  def open?(_), do: false

  @impl Quiver.Conn
  def close(%__MODULE__{h3_conn: nil} = conn), do: {:ok, conn}

  def close(%__MODULE__{h3_conn: pid} = conn) do
    _ = :quic_h3.close(pid)
    {:ok, %{conn | h3_conn: nil}}
  end

  @impl Quiver.Conn
  def open_request(%__MODULE__{h3_conn: pid} = conn, method, path, headers, body) do
    opts = if empty_body?(body), do: %{}, else: %{end_stream: false}

    with {:ok, h3_headers} <- to_h3_headers(method, path, headers, conn),
         {:ok, stream_id} <- :quic_h3.request(pid, h3_headers, opts),
         :ok <- send_body(pid, stream_id, body) do
      ref = make_ref()

      conn = %{
        conn
        | ref_to_stream_id: Map.put(conn.ref_to_stream_id, ref, stream_id),
          stream_id_to_ref: Map.put(conn.stream_id_to_ref, stream_id, ref)
      }

      {:ok, conn, ref}
    else
      {:error, reason} -> {:error, conn, reason}
    end
  end

  defp empty_body?(nil), do: true
  defp empty_body?(""), do: true
  defp empty_body?([]), do: true
  defp empty_body?(_), do: false

  @impl Quiver.Conn
  def request(conn, method, path, headers, body) do
    case open_request(conn, method, path, headers, body) do
      {:ok, conn, ref} ->
        collect_response(conn, ref, %{status: nil, headers: [], body: [], trailers: []})

      {:error, conn, reason} ->
        {:error, conn, reason}
    end
  end

  @impl Quiver.Conn
  def stream(%__MODULE__{h3_conn: pid} = conn, {:quic_h3, pid, event}) do
    {fragments, conn} = handle_event(event, conn, [])
    {:ok, conn, Enum.reverse(fragments)}
  end

  def stream(_conn, _msg), do: :unknown

  @impl Quiver.Conn
  def cancel(%__MODULE__{h3_conn: nil} = conn, _ref), do: {:ok, conn}

  def cancel(%__MODULE__{h3_conn: pid} = conn, ref) do
    case Map.fetch(conn.ref_to_stream_id, ref) do
      {:ok, sid} ->
        _ = :quic_h3.cancel(pid, sid)
        {:ok, drop_stream(conn, ref, sid)}

      :error ->
        {:ok, conn}
    end
  end

  @impl Quiver.Conn
  def open_request_count(%__MODULE__{ref_to_stream_id: m}), do: map_size(m)

  @impl Quiver.Conn
  def max_concurrent_streams(%__MODULE__{peer_max_streams: n}), do: n

  @doc """
  Builds the HTTP/3 header list for a request: pseudo-headers in the
  required order followed by user headers (lowercased). Rejects
  connection-specific headers forbidden by RFC 9114 §4.2.

  The origin is a `{scheme, host, port}` tuple. Authority omits the
  default port for the scheme (`443` for `:https`, `80` for `:http`).
  """
  @spec build_headers(
          atom(),
          String.t(),
          Quiver.Conn.headers(),
          {atom(), String.t(), :inet.port_number()}
        ) ::
          {:ok, [{binary(), binary()}]} | {:error, term()}
  def build_headers(method, path, headers, {scheme, host, port}) do
    pseudo = [
      {<<":method">>, method |> Atom.to_string() |> String.upcase()},
      {<<":scheme">>, Atom.to_string(scheme)},
      {<<":path">>, path},
      {<<":authority">>, authority(host, port, scheme)}
    ]

    case validate_user_headers(headers) do
      {:ok, user} -> {:ok, pseudo ++ user}
      {:error, _} = err -> err
    end
  end

  @doc """
  Backwards-compatible wrapper around `build_headers/4` for a
  `%Quiver.Conn.HTTP3{}` struct.
  """
  @spec to_h3_headers(atom(), String.t(), Quiver.Conn.headers(), t()) ::
          {:ok, [{binary(), binary()}]} | {:error, term()}
  def to_h3_headers(method, path, headers, %__MODULE__{host: host, port: port, scheme: scheme}) do
    build_headers(method, path, headers, {scheme, host, port})
  end

  @doc """
  Returns the peer's advertised initial-max-streams-bidi limit, falling
  back to the supplied integer if the underlying `:quic` runtime does
  not expose `get_peer_transport_params/1` (older versions).
  """
  @spec query_peer_max_streams(pid(), non_neg_integer()) :: non_neg_integer()
  def query_peer_max_streams(h3_conn, fallback) when is_pid(h3_conn) and is_integer(fallback) do
    if function_exported?(:quic, :get_peer_transport_params, 1) do
      try do
        case :quic.get_peer_transport_params(:quic_h3.get_quic_conn(h3_conn)) do
          {:ok, tp} -> min(Map.get(tp, :initial_max_streams_bidi, fallback), fallback)
          _ -> fallback
        end
      catch
        :error, :undef -> fallback
        :exit, _ -> fallback
      end
    else
      fallback
    end
  end

  defp build_h3_opts(opts) do
    base = %{verify: Keyword.get(opts, :verify, :verify_peer)}

    base
    |> maybe_put(:cacerts, Keyword.get(opts, :cacerts))
    |> maybe_put(:settings, Keyword.get(opts, :h3_settings))
    |> maybe_put(:quic_opts, Keyword.get(opts, :quic_opts))
  end

  defp maybe_put(map, _k, nil), do: map
  defp maybe_put(map, _k, :default), do: map
  defp maybe_put(map, _k, v) when is_map(v) and map_size(v) == 0, do: map
  defp maybe_put(map, k, v), do: Map.put(map, k, v)

  defp validate_user_headers(headers) do
    Enum.reduce_while(headers, {:ok, []}, fn {k, v}, {:ok, acc} ->
      lower = String.downcase(to_string(k))

      if lower in @forbidden_headers do
        {:halt, {:error, {:forbidden_header, lower}}}
      else
        {:cont, {:ok, [{lower, to_string(v)} | acc]}}
      end
    end)
    |> case do
      {:ok, list} -> {:ok, Enum.reverse(list)}
      err -> err
    end
  end

  defp authority(host, 443, :https), do: host
  defp authority(host, 80, :http), do: host
  defp authority(host, port, _), do: "#{host}:#{port}"

  defp send_body(_pid, _sid, nil), do: :ok
  defp send_body(_pid, _sid, ""), do: :ok
  defp send_body(_pid, _sid, []), do: :ok

  defp send_body(pid, sid, body) when is_binary(body) do
    :quic_h3.send_data(pid, sid, body, true)
  end

  defp send_body(pid, sid, body) when is_list(body) do
    :quic_h3.send_data(pid, sid, IO.iodata_to_binary(body), true)
  end

  defp send_body(_pid, _sid, {:stream, _enum}),
    do:
      {:error,
       ArgumentError.exception(
         message:
           "streaming bodies must go through a pool — Conn.HTTP3 only supports buffered bodies"
       )}

  defp handle_event({:response, sid, status, headers}, conn, acc) do
    case Map.fetch(conn.stream_id_to_ref, sid) do
      {:ok, ref} -> {[{:headers, ref, headers}, {:status, ref, status} | acc], conn}
      :error -> {acc, conn}
    end
  end

  defp handle_event({:data, sid, data, false}, conn, acc) do
    case Map.fetch(conn.stream_id_to_ref, sid) do
      {:ok, ref} -> {[{:data, ref, data} | acc], conn}
      :error -> {acc, conn}
    end
  end

  defp handle_event({:data, sid, data, true}, conn, acc) do
    case Map.fetch(conn.stream_id_to_ref, sid) do
      {:ok, ref} ->
        conn = drop_stream(conn, ref, sid)
        acc = if data == <<>>, do: acc, else: [{:data, ref, data} | acc]
        {[{:done, ref} | acc], conn}

      :error ->
        {acc, conn}
    end
  end

  defp handle_event({:trailers, sid, trailers}, conn, acc) do
    case Map.fetch(conn.stream_id_to_ref, sid) do
      {:ok, ref} -> {[{:trailers, ref, trailers} | acc], conn}
      :error -> {acc, conn}
    end
  end

  defp handle_event({:stream_reset, sid, code}, conn, acc) do
    case Map.fetch(conn.stream_id_to_ref, sid) do
      {:ok, ref} ->
        err = H3StreamError.exception(stream_id: sid, code: code)
        {[{:error, ref, err} | acc], drop_stream(conn, ref, sid)}

      :error ->
        {acc, conn}
    end
  end

  defp handle_event(:closed, conn, acc) do
    err = QUICTransportError.exception(code: 0, reason: :closed)
    fail_all(conn, acc, err)
  end

  defp handle_event({:error, code, reason}, conn, acc) do
    err = QUICTransportError.exception(code: code, reason: reason)
    fail_all(conn, acc, err)
  end

  defp handle_event(_other, conn, acc), do: {acc, conn}

  defp fail_all(conn, acc, err) do
    errors = Enum.map(conn.ref_to_stream_id, fn {r, _} -> {:error, r, err} end)
    {errors ++ acc, %{conn | ref_to_stream_id: %{}, stream_id_to_ref: %{}, h3_conn: nil}}
  end

  defp drop_stream(conn, ref, sid) do
    %{
      conn
      | ref_to_stream_id: Map.delete(conn.ref_to_stream_id, ref),
        stream_id_to_ref: Map.delete(conn.stream_id_to_ref, sid)
    }
  end

  defp collect_response(%__MODULE__{h3_conn: pid} = conn, ref, acc) do
    receive do
      {:quic_h3, ^pid, _} = msg ->
        {:ok, conn, fragments} = stream(conn, msg)

        case fold_fragments(fragments, ref, acc) do
          {:done, acc} -> {:ok, conn, build_response(acc)}
          {:error, err} -> {:error, conn, err}
          {:cont, acc} -> collect_response(conn, ref, acc)
        end
    after
      conn.recv_timeout -> {:error, conn, :recv_timeout}
    end
  end

  defp fold_fragments([], _ref, acc), do: {:cont, acc}

  defp fold_fragments([{:status, ref, s} | rest], ref, acc),
    do: fold_fragments(rest, ref, %{acc | status: s})

  defp fold_fragments([{:headers, ref, hs} | rest], ref, acc),
    do: fold_fragments(rest, ref, %{acc | headers: hs})

  defp fold_fragments([{:trailers, ref, hs} | rest], ref, acc),
    do: fold_fragments(rest, ref, %{acc | trailers: hs})

  defp fold_fragments([{:data, ref, d} | rest], ref, acc),
    do: fold_fragments(rest, ref, %{acc | body: [acc.body, d]})

  defp fold_fragments([{:done, ref} | _], ref, acc), do: {:done, acc}
  defp fold_fragments([{:error, ref, err} | _], ref, _acc), do: {:error, err}
  defp fold_fragments([_ | rest], ref, acc), do: fold_fragments(rest, ref, acc)

  defp build_response(%{status: status, headers: headers, body: body, trailers: trailers}) do
    %Response{
      status: status,
      headers: headers,
      body: IO.iodata_to_binary(body),
      trailers: trailers
    }
  end
end
