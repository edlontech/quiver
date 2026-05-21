defmodule Quiver.HTTP3 do
  @moduledoc """
  HTTP/3 datagram channel API (RFC 9297).

  Opens an HTTP/3 request stream that is kept open without auto-ending and
  drives a user handler with response, datagram, stream-data, trailer, and
  close events. The handler may call `send_datagram/2` and
  `max_datagram_size/1` against an opaque `%Quiver.HTTP3.Channel{}` to push
  datagrams back.

  ## Sample usage

      {:ok, final_acc} =
        Quiver.HTTP3.open_datagram_channel(
          "https://h3.example/wt/session",
          [method: :connect, protocol: "webtransport"],
          fn
            {:response, 200, _hs}, channel, acc ->
              Quiver.HTTP3.send_datagram(channel, "hello")
              {:cont, acc}

            {:datagram, _payload}, _ch, acc ->
              {:cont, acc}

            {:closed, _reason}, _ch, acc ->
              {:halt, acc}
          end,
          []
        )

  See `guides/http3.md` for the full cookbook including extended CONNECT
  and the WebTransport-style `:protocol` header.
  """

  alias Quiver.Error.H3DatagramError
  alias Quiver.Error.H3DatagramsDisabled
  alias Quiver.HTTP3.Channel
  alias Quiver.Pool.HTTP3, as: PoolHTTP3
  alias Quiver.Pool.Manager
  alias Quiver.Telemetry

  @default_name Quiver.Pool
  @default_receive_timeout 15_000
  @default_open_timeout 5_000

  @type status :: 100..599
  @type headers :: [{binary(), binary()}]
  @type payload :: binary()

  @type close_reason ::
          :peer
          | {:reset, non_neg_integer()}
          | {:goaway, non_neg_integer()}
          | {:transport, Quiver.Error.QUICTransportError.t()}

  @type event ::
          {:response, status(), headers()}
          | {:datagram, payload()}
          | {:stream_data, binary()}
          | {:trailers, headers()}
          | {:closed, close_reason()}

  @type handler ::
          (event(), Channel.t(), term() -> {:cont, term()} | {:halt, term()})

  @doc """
  Opens an HTTP/3 datagram channel and drives `handler` until it halts or
  the channel closes.

  Synchronous from the caller's perspective: the calling process owns the
  event mailbox and runs the reduce loop.

  See module docs for options and event semantics.

  Returns `{:ok, acc}` on normal close or halt, `{:error, reason}` on
  open failure / timeout / disabled datagrams.
  """
  @spec open_datagram_channel(String.t(), keyword(), handler(), term()) ::
          {:ok, term()} | {:error, term()}
  def open_datagram_channel(url, opts, handler, acc) when is_function(handler, 3) do
    name = Keyword.get(opts, :name, @default_name)
    receive_timeout = Keyword.get(opts, :receive_timeout, @default_receive_timeout)
    open_timeout = Keyword.get(opts, :open_timeout, @default_open_timeout)
    require_datagrams = Keyword.get(opts, :require_datagrams, true)
    method = Keyword.get(opts, :method, :get)
    headers = Keyword.get(opts, :headers, [])
    channel_opts = Keyword.take(opts, [:protocol])

    uri = URI.parse(url)
    origin = {scheme_to_atom(uri.scheme), uri.host, uri.port || default_port(uri.scheme)}
    path = build_path(uri)
    metadata = %{origin: origin, method: method, path: path}

    ctx = %{
      name: name,
      origin: origin,
      method: method,
      path: path,
      headers: headers,
      channel_opts: channel_opts,
      open_timeout: open_timeout,
      receive_timeout: receive_timeout,
      require_datagrams: require_datagrams
    }

    Telemetry.span(Telemetry.connection_http3_channel_event_prefix(), metadata, fn ->
      result = do_open_channel(ctx, handler, acc)

      extra =
        case result do
          {:ok, _} -> %{close_reason: :normal, status: nil}
          {:error, reason} -> %{close_reason: {:error, reason}, status: nil}
        end

      {result, Map.merge(metadata, extra)}
    end)
  end

  @doc """
  Sends a datagram on `channel`. Bypasses the pool worker by calling
  `:quic_h3.send_datagram/3` directly for hot-path speed.

  Returns `:ok` on success or `{:error, exception}` where the exception is
  either `Quiver.Error.H3DatagramsDisabled` (peer didn't negotiate) or
  `Quiver.Error.H3DatagramError` (transport / sizing / lifecycle).
  """
  @spec send_datagram(Channel.t(), iodata()) :: :ok | {:error, Exception.t()}
  def send_datagram(%Channel{h3_conn: pid, stream_id: sid} = ch, data) do
    case :quic_h3.send_datagram(pid, sid, data) do
      :ok ->
        emit_datagram_sent(ch, IO.iodata_length(data))
        :ok

      {:error, reason} ->
        emit_datagram_send_failed(ch, reason)
        {:error, map_datagram_error(reason, ch)}
    end
  end

  @doc """
  Returns the maximum usable datagram payload size on `channel`.

  Returns `0` when the extension is not negotiated. Otherwise the value
  is the per-datagram payload limit after subtracting the QSID varint
  prefix `:quic_h3` prepends internally.
  """
  @spec max_datagram_size(Channel.t()) :: non_neg_integer()
  def max_datagram_size(%Channel{h3_conn: pid, stream_id: sid}) do
    :quic_h3.max_datagram_size(pid, sid)
  end

  @doc """
  Returns `true` if both peers negotiated SETTINGS_H3_DATAGRAM=1 and the
  underlying QUIC connection has `max_datagram_frame_size > 0`.
  """
  @spec h3_datagrams_enabled?(Channel.t()) :: boolean()
  def h3_datagrams_enabled?(%Channel{h3_conn: pid}) do
    :quic_h3.h3_datagrams_enabled(pid)
  end

  # -- Internals --

  defp do_open_channel(ctx, handler, acc) do
    with {:ok, pool} <- Manager.get_pool(ctx.name, ctx.origin),
         {:ok, %Channel{} = channel, cref} <-
           PoolHTTP3.open_channel(pool, ctx.method, ctx.path, ctx.headers, ctx.channel_opts,
             open_timeout: ctx.open_timeout
           ),
         :ok <- maybe_enforce_datagrams(channel, cref, ctx.require_datagrams, ctx.origin) do
      handler_loop(channel, cref, handler, acc, ctx.receive_timeout)
    end
  end

  defp maybe_enforce_datagrams(_channel, _cref, false, _origin), do: :ok

  defp maybe_enforce_datagrams(%Channel{h3_conn: pid} = channel, cref, true, origin) do
    if :quic_h3.h3_datagrams_enabled(pid) do
      :ok
    else
      send(channel.worker_pid, {:cancel_stream, cref, self()})
      drain_remaining(cref)
      {:error, H3DatagramsDisabled.exception(origin: origin)}
    end
  end

  defp handler_loop(channel, cref, fun, acc, timeout) do
    receive do
      {:quiver_h3_channel, ^cref, event} ->
        channel = update_channel(channel, event)
        terminal? = match?({:closed, _}, event) or match?({:trailers, _}, event)

        case fun.(event, channel, acc) do
          {:cont, acc} when not terminal? ->
            handler_loop(channel, cref, fun, acc, timeout)

          {:cont, acc} ->
            {:ok, acc}

          {:halt, value} ->
            send(channel.worker_pid, {:cancel_stream, cref, self()})
            drain_remaining(cref)
            {:ok, value}
        end
    after
      timeout ->
        send(channel.worker_pid, {:cancel_stream, cref, self()})
        drain_remaining(cref)
        {:error, :recv_timeout}
    end
  end

  defp update_channel(channel, {:response, status, headers}) do
    %{channel | status: status, response_headers: headers}
  end

  defp update_channel(channel, _event), do: channel

  defp drain_remaining(cref) do
    receive do
      {:quiver_h3_channel, ^cref, _} -> drain_remaining(cref)
    after
      0 -> :ok
    end
  end

  # -- Error mapping --

  defp map_datagram_error(:h3_datagrams_disabled, %Channel{origin: o}) do
    H3DatagramsDisabled.exception(origin: o)
  end

  defp map_datagram_error(:datagrams_not_supported, %Channel{origin: o}) do
    H3DatagramsDisabled.exception(origin: o)
  end

  defp map_datagram_error(:datagram_too_large, _ch) do
    %{H3DatagramError.exception(reason: :too_large) | class: :invalid}
  end

  defp map_datagram_error(:datagram_too_large_for_path, _ch) do
    H3DatagramError.exception(reason: :too_large_for_path)
  end

  defp map_datagram_error(:congestion_limited, _ch) do
    H3DatagramError.exception(reason: :congestion_limited)
  end

  defp map_datagram_error(:unknown_stream, _ch) do
    H3DatagramError.exception(reason: :unknown_stream)
  end

  defp map_datagram_error(other, _ch) do
    H3DatagramError.exception(reason: other)
  end

  # -- Telemetry emitters (caller-side) --

  defp emit_datagram_sent(%Channel{origin: o, stream_id: sid}, bytes) do
    :telemetry.execute(
      Telemetry.connection_http3_datagram_event_prefix() ++ [:sent],
      %{bytes: bytes},
      %{origin: o, stream_id: sid}
    )
  end

  defp emit_datagram_send_failed(%Channel{origin: o, stream_id: sid}, reason) do
    :telemetry.execute(
      Telemetry.connection_http3_datagram_event_prefix() ++ [:send_failed],
      %{system_time: System.system_time()},
      %{origin: o, stream_id: sid, reason: reason}
    )
  end

  # -- URI helpers --

  defp scheme_to_atom("https"), do: :https
  defp scheme_to_atom("http"), do: :http

  defp default_port("https"), do: 443
  defp default_port("http"), do: 80
  defp default_port(_), do: 80

  defp build_path(%URI{path: nil, query: nil}), do: "/"
  defp build_path(%URI{path: path, query: nil}), do: path
  defp build_path(%URI{path: nil, query: query}), do: "/?#{query}"
  defp build_path(%URI{path: path, query: query}), do: "#{path}?#{query}"
end
