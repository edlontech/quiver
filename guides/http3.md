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

You can subscribe with `:telemetry.attach_many/4`:

```elixir
:telemetry.attach_many(
  "myapp-quiver-h3",
  [
    [:quiver, :connection, :http3, :start],
    [:quiver, :connection, :http3, :stop],
    [:quiver, :connection, :http3, :exception],
    [:quiver, :connection, :http3, :draining]
  ],
  fn event, measurements, metadata, _ ->
    Logger.info("h3 event=#{inspect(event)} meta=#{inspect(metadata)} meas=#{inspect(measurements)}")
  end,
  nil
)
```

The prefix is exposed for convenience as
`Quiver.Telemetry.connection_http3_event_prefix/0`.

## Known limitations (v1)

- **No Alt-Svc / HTTPS-record discovery.** HTTP/3 is opt-in per pool. Quiver
  will not transparently upgrade an HTTPS pool to HTTP/3.
- **No proxy support.** CONNECT tunnelling is not implemented for HTTP/3.
  Combining `protocol: :http3` with a `proxy:` option fails validation.
- **No connection migration API.** Path migration when the local address
  changes (e.g. switching networks) is not exposed. `:quic_h3` may already
  support it on the wire; the Quiver-level API does not.
- **No HTTP/3 datagrams support.** Quiver does not opt in to RFC 9297
  datagrams at the QUIC layer, so inbound datagrams are never delivered to
  the worker and there is no public send API. Datagram support is tracked
  as a future feature.
- **No server push.** HTTP/3 server push is not implemented; pushed streams
  from the peer are ignored.
- **No 0-RTT.** All handshakes are full 1-RTT in v1.

These are tracked separately and may land in future releases. None of them
preclude future support; the worker exposes hook points (telemetry, error
types, message dispatch) deliberately to make the additions cheap.

## Benchmarking

A protocol-isolated benchmark is included:

```bash
mix bench.http3
```

This compares Quiver HTTP/2 against Quiver HTTP/3 on the same workload
(GETs at 1 KB and 1 MB plus a small POST). Finch is omitted because it does
not support HTTP/3. Set `BENCH_SMOKE=1` for a fast smoke-test run.
