# HTTP/3

Quiver supports HTTP/3 over QUIC via the `:quic_h3` library. HTTP/3 must be
opted into per pool; Quiver will not auto-upgrade an HTTPS origin to HTTP/3
based on Alt-Svc or any other discovery mechanism.

## When to use HTTP/3

HTTP/3 inherits HTTP/2's multiplexing model but moves the transport from
TCP+TLS to QUIC (UDP). The practical wins:

- No head-of-line blocking between streams on a single connection (TCP forces
  serial bytes; QUIC does not).
- Faster handshakes (typically 1-RTT, 0-RTT in some cases).
- Connection survival across path changes once migration support lands (not
  in v1; see "Known limitations" below).

HTTP/3 is most useful on lossy networks or when you have many concurrent
streams over one logical connection. For low-latency, low-loss intranets,
HTTP/2 will frequently be competitive or faster.

## Configuration

HTTP/3 is opted into per pool via `protocol: :http3`:

```elixir
children = [
  {Quiver.Supervisor,
    pools: %{
      "https://h3.example.com" => [
        protocol: :http3,
        max_connections: 4,
        initial_max_streams: 100,
        quic_opts: %{
          max_idle_timeout: 30_000,
          max_udp_payload_size: 1452
        },
        h3_settings: %{
          qpack_max_table_capacity: 4096,
          qpack_blocked_streams: 16
        },
        verify: :verify_peer
      ],
      default: [size: 10]
    }
  }
]
```

### Pool options

| Option | Default | Description |
|---|---|---|
| `protocol` | `:auto` | Set to `:http3` to use this pool over QUIC. |
| `max_connections` | `1` | Per-origin upper bound on QUIC connections. Raise to parallelise large workloads. |
| `initial_max_streams` | `100` | Local guess for the peer's stream limit; used until the handshake supplies the actual value. |
| `quic_opts` | `%{}` | Map passed straight to `:quic.connect/3` for transport-level tuning (idle timeout, MTU, etc.). |
| `h3_settings` | `%{}` | Map of HTTP/3 `SETTINGS` to advertise to the peer (QPACK capacity, blocked streams, etc.). |
| `stream_idle_timeout` | `30_000` | Milliseconds of consumer inactivity before a stream is reset and the caller receives `:idle_timeout`. |
| `verify` | `:verify_peer` | Forwarded to `:quic_h3`; use `:verify_none` for self-signed test setups. |
| `cacerts` | (none) | DER-encoded CA list for `verify_peer`. |

### HTTPS-only

HTTP/3 is HTTPS-only. Quiver enforces this at configuration time:

- A pool with `protocol: :http3` and any `http://` origin (in the same rule)
  fails validation with `Quiver.Error.InvalidPoolRule`.
- A `default` rule with `protocol: :http3` is accepted, but requests against
  `http://` URLs will fall through to a different rule (or fail to route).

### Proxy not supported

HTTP/3 over HTTP CONNECT-style proxies is not supported in v1. Combining
`protocol: :http3` with any `proxy:` option in the same pool config raises
`Quiver.Error.InvalidPoolOpts` at validation time. MASQUE (RFC 9484) support
is a likely future addition; track the project changelog.

## Making requests

The top-level API is unchanged -- the protocol is selected by the matching
pool, not the call site:

```elixir
{:ok, %Quiver.Response{status: 200, body: body}} =
  Quiver.new(:get, "https://h3.example.com/items/42")
  |> Quiver.request()

{:ok, %Quiver.Response{status: 200}} =
  Quiver.new(:post, "https://h3.example.com/items")
  |> Quiver.header("content-type", "application/json")
  |> Quiver.body(~s({"name": "thing"}))
  |> Quiver.request()
```

### Streaming responses

```elixir
{:ok, %Quiver.StreamResponse{status: 200, body: body_stream}} =
  Quiver.new(:get, "https://h3.example.com/events")
  |> Quiver.stream_request()

body_stream
|> Stream.each(&IO.write/1)
|> Stream.run()
```

Backpressure works the same way as HTTP/2: the worker buffers chunks until
the consumer demands them, and aborting the stream cancels the QUIC stream.

### Streaming request bodies

```elixir
upload = Stream.repeatedly(fn -> :crypto.strong_rand_bytes(64 * 1024) end) |> Stream.take(16)

{:ok, _resp} =
  Quiver.new(:post, "https://h3.example.com/upload")
  |> Quiver.header("content-type", "application/octet-stream")
  |> Quiver.stream_body(upload)
  |> Quiver.request()
```

Quiver opens an HTTP/3 stream without `END_STREAM`, then pumps each
enumerable element as a DATA frame, and finally sends an empty DATA with
`END_STREAM` set. If the producer raises or the caller dies mid-stream,
Quiver cancels the QUIC stream with the appropriate H3 error code.

## Datagrams

Quiver supports HTTP/3 datagrams as a callback-driven channel API. The
extension is negotiated automatically on every `protocol: :http3` pool.

```elixir
{:ok, final_acc} =
  Quiver.HTTP3.open_datagram_channel(
    "https://h3.example/wt/session",
    [method: :connect, protocol: "webtransport"],
    fn
      {:response, 200, _hs}, channel, acc ->
        Quiver.HTTP3.send_datagram(channel, "hello")
        {:cont, acc}

      {:datagram, payload}, _ch, acc ->
        IO.inspect(payload, label: "got")
        {:cont, [payload | acc]}

      {:closed, _reason}, _ch, acc ->
        {:halt, Enum.reverse(acc)}
    end,
    []
  )
```

The handler is invoked synchronously by `open_datagram_channel/4` for
every event in arrival order:

- `{:response, status, headers}` -- usually the first event, but RFC 9297
  permits a `:datagram` to arrive first. Tolerate `channel.status == nil`
  in your datagram clause.
- `{:datagram, payload}` -- inbound datagrams. Best-effort, unreliable,
  unordered (RFC 9221). Drop quietly if your application can't keep up.
- `{:stream_data, bytes}` -- DATA frames on the underlying H/3 stream.
  Most useful for protocols that mix bytes and datagrams.
- `{:trailers, headers}` -- HTTP/3 trailers; terminal.
- `{:closed, reason}` -- channel closed; terminal. Reason is `:peer`,
  `{:reset, code}`, `{:goaway, gid}`, or `{:transport, exception}`.

Use `:method, :connect` and a `:protocol` opt to open an extended-CONNECT
session, required for WebTransport, RFC 9298
Connect-UDP, and MASQUE. With `:method, :get` and a server that closes
the stream after `200 OK`, the channel will receive `:response` and then
`:closed, :peer` immediately, with no useful window to send datagrams.

### Send / query helpers

```elixir
Quiver.HTTP3.send_datagram(channel, iodata)       # :ok | {:error, _}
Quiver.HTTP3.max_datagram_size(channel)           # usable payload size
Quiver.HTTP3.h3_datagrams_enabled?(channel)       # peer negotiation status
```

### Options

| Option | Default | Meaning |
|---|---|---|
| `:method` | `:get` | HTTP method (`:connect` for extended CONNECT). |
| `:protocol` | `nil` | `:protocol` pseudo-header value (e.g. `"webtransport"`). |
| `:headers` | `[]` | Extra user headers. |
| `:name` | `Quiver.Pool` | Supervisor instance. |
| `:receive_timeout` | `15_000` | Per-event ms deadline. |
| `:open_timeout` | `5_000` | Initial open-call ms deadline. |
| `:require_datagrams` | `true` | Fail fast if the peer didn't negotiate. |

### Errors

- `Quiver.Error.H3DatagramsDisabled` (`:transient`) -- peer didn't negotiate.
- `Quiver.Error.H3DatagramError` -- wraps RFC 9221 transport errors. Class
  is `:transient` except for `:too_large` (which is `:invalid` because the
  caller must shrink the payload to fit `max_datagram_size/1`).

### Telemetry

In addition to the connection-level events listed below, the datagram
channel emits events nested under `[:quiver, :connection, :http3, ...]`:

| Event | Measurements | Metadata |
|---|---|---|
| `[:quiver, :connection, :http3, :datagram, :sent]` | `bytes` | `origin, stream_id` |
| `[:quiver, :connection, :http3, :datagram, :received]` | `bytes` | `origin, stream_id` |
| `[:quiver, :connection, :http3, :datagram, :send_failed]` | `system_time` | `origin, stream_id, reason` |
| `[:quiver, :connection, :http3, :datagram, :dropped]` | `system_time` | `origin, stream_id, reason` |
| `[:quiver, :connection, :http3, :channel, :start]` | `system_time` | `origin, method, path` |
| `[:quiver, :connection, :http3, :channel, :stop]` | `duration` | `origin, close_reason` |
| `[:quiver, :connection, :http3, :channel, :exception]` | `duration` | `origin, kind, reason` |

The full list and current measurement/metadata shape is documented in
`Quiver.Telemetry`.

## Telemetry

In addition to the protocol-agnostic `[:quiver, :request, ...]` span and
pool queue events, HTTP/3 emits connection-level events under
`[:quiver, :connection, :http3, ...]`:

| Event | Measurements | Metadata |
|---|---|---|
| `[:quiver, :connection, :http3, :start]` | `system_time` | `origin`, `pool_pid` |
| `[:quiver, :connection, :http3, :stop]` | `duration` | `origin`, `peer_max_streams` |
| `[:quiver, :connection, :http3, :exception]` | `duration` | `origin`, `reason`, `kind` |
| `[:quiver, :connection, :http3, :draining]` | `system_time` | `origin`, `last_stream_id`, `error_code` |

`:start` fires before `:quic_h3.connect/3` is called. `:stop` fires when the
worker enters `:connected` (handshake complete and peer SETTINGS received).
`:exception` fires when the handshake fails. `:draining` fires once per
connection when a peer GOAWAY is first observed or self-initiated;
subsequent GOAWAY frames that only tighten the drain are not re-emitted.
The in-flight stream count keeps dropping until the connection terminates
with `:normal`.

The prefix is exposed for convenience as
`Quiver.Telemetry.connection_http3_event_prefix/0`.

## TODOs

- **No 0-RTT.** All handshakes are full 1-RTT. Session tickets emitted by the
  server are silently dropped because `:quic_h3` does not forward the
  `{session_ticket, _}` event to its owner, and the H3 state machine rejects
  requests pre-`connected` so the underlying QUIC's 0-RTT machinery cannot
  be reached. We need to patch the upstream before implementing this.
- **No WebTransport / Connect-UDP / MASQUE.**
- **No proxy support.** CONNECT tunnelling is not implemented for HTTP/3.
  Combining `protocol: :http3` with a `proxy:` option fails validation.
  HTTP/1.1 and HTTP/2 already support CONNECT proxies; HTTP/3 would need
  either CONNECT-UDP (RFC 9298) or MASQUE (RFC 9484), both of which are
  separate projects on top of the datagrams work.
- **No server push.** HTTP/3 server push is not implemented; pushed streams
  from the peer are ignored. `:quic_h3` exports the necessary
  (`set_max_push_id/2`, push event handling), but server push is almost
  not used, so i'll only add it if there's demand.
- **No Alt-Svc / HTTPS-record discovery.** HTTP/3 is opt-in per pool. Quiver
  will not transparently upgrade an HTTPS pool to HTTP/3.
- **No connection migration API.** Path migration when the local address
  changes (e.g. switching networks) is not exposed.

## Benchmarking

A protocol-isolated benchmark is included:

```bash
mix bench.http3
```

This compares Quiver HTTP/2 against Quiver HTTP/3 on the same workload
(GETs at 1 KB and 1 MB plus a small POST). Finch is omitted because it does
not support HTTP/3. Set `BENCH_SMOKE=1` for a fast smoke-test run.
