# Architecture

Quiver is organized in four layers: Client API, Pool, Connection, and Transport.
Each layer has a clear responsibility and communicates with the layer below through
well-defined interfaces.

## Request Flow

```
Quiver.request/3
  |> Pool.Manager.get_pool/2       (stateless lookup / lazy start)
  |> Pool.request/6                (HTTP1, HTTP2, or HTTP3 pool)
  |> Conn.request/6                (wire protocol)
  |> Transport.send/recv           (SSL, TCP, or QUIC via :quic_h3)
```

## Client API Layer

The top-level `Quiver` module provides the public interface:

- `Quiver.new/2` -- build a request struct
- `Quiver.header/3`, `Quiver.body/2` -- attach headers and body
- `Quiver.request/3` -- execute and receive the full response
- `Quiver.stream_request/3` -- execute with a lazy body stream

The client API is stateless. It resolves the target origin from the URL,
finds (or starts) a pool through the Manager, then delegates to the pool.

## Pool Manager

`Quiver.Pool.Manager` is a stateless router. On the hot path it looks up an
existing pool via `Registry`. On the cold path (first request to an origin)
it starts a new pool under `DynamicSupervisor` and the pool self-registers.

Protocol detection uses `:persistent_term`: each pool writes
`{PoolModule, pid} => true` on init. The manager checks each registered
pool module to dispatch to `Pool.HTTP1`, `Pool.HTTP2`, or `Pool.HTTP3`.

## Pool Layer

Both pool implementations conform to the `Quiver.Pool` behaviour, which defines
`request/6` and `stats/1` callbacks.

### HTTP/1 Pool

`Quiver.Pool.HTTP1` uses [NimblePool](https://github.com/dashbitco/nimble_pool) for
connection pooling. Connections are created lazily in the caller's process and
checked back in after each request. The pool maintains stats (idle, active, queued)
in an ETS table.

For streaming, the pool uses a keeper task pattern: a background task holds the
NimblePool slot while the caller consumes the body stream, ensuring the connection
stays checked out for the duration of the stream.

### HTTP/2 Pool

`Quiver.Pool.HTTP2` uses a two-level architecture:

1. **Coordinator** (`Pool.HTTP2`) -- a `GenStateMachine` per origin with `:idle` and
   `:connected` states. Routes callers to connections with available stream slots.
   Manages the queue of waiting callers when all slots are occupied.

2. **Connection worker** (`Pool.HTTP2.Connection`) -- a `GenStateMachine` per connection
   with `:connected` and `:draining` states. Owns the HTTP/2 connection, manages
   stream multiplexing, and handles GOAWAY graceful drain.

The coordinator uses a two-phase caller model: the caller makes a `gen_statem` call to
the coordinator, which forwards `{:forward_request, from, ...}` to a worker. The worker
replies directly to the original caller's `from`, keeping the coordinator out of the
data path.

### HTTP/3 Pool

`Quiver.Pool.HTTP3` mirrors the HTTP/2 two-level architecture:

1. **Coordinator** (`Pool.HTTP3`) -- a `GenStateMachine` per origin (`:idle` /
   `:connected` states). Routes callers to connection workers with available
   stream slots, eagerly expanding up to `max_connections`, and queues callers
   when all slots are saturated.

2. **Connection worker** (`Pool.HTTP3.Connection`) -- a `GenStateMachine` per
   QUIC connection with `:connecting`, `:connected`, and `:draining` states.
   Owns the `:quic_h3` connection pid, translates QUIC events into caller
   replies, handles GOAWAY-driven drain, and emits connection telemetry.

The HTTP/3 handshake is asynchronous: the worker starts in `:connecting`,
queues any requests forwarded during the handshake, and flushes them on
transition to `:connected`. It notifies the coordinator via
`{:connection_ready, pid, peer_max_streams}` so the coordinator only picks
fully-established connections.

The coordinator uses the same two-phase caller model as HTTP/2: workers reply
directly to the original caller's `from`. Request body streaming uses linked
tasks per stream that pump enumerables back to the worker as
`{:stream_chunk, sid, chunk}` / `{:stream_end, sid}` info messages.

## Connection Layer

The `Quiver.Conn` behaviour defines the wire protocol interface. Two implementations:

### HTTP/1.1

`Quiver.Conn.HTTP1` implements synchronous request/response. Sub-modules handle
parsing (`HTTP1.Parse`) and request formatting (`HTTP1.Request`). Supports
keep-alive for connection reuse and chunked transfer encoding.

### HTTP/2

`Quiver.Conn.HTTP2` is a stateless data struct (not a process). It handles:

- TLS+ALPN negotiation (no h2c/cleartext upgrade)
- HPACK header compression via the `hpax` library
- Flow control with per-stream and connection-level windows
- Frame codec (`HTTP2.Frame`) for encoding and decoding

The HTTP/2 connection struct is owned and mutated by the Connection worker process.

### HTTP/3

`Quiver.Conn.HTTP3` wraps the `:quic_h3` library (which itself owns the QUIC
connection and HTTP/3 framing layer). Unlike `Conn.HTTP2` it is not a
self-contained codec; framing, HPACK/QPACK, and flow control all live inside
`:quic_h3`. The Quiver-side module focuses on:

- Building HTTP/3 pseudo-header lists from `(method, path, headers, origin)`
  tuples (validating forbidden headers and normalising case).
- Querying peer settings such as `peer_max_streams`.
- Mapping QUIC and HTTP/3 error codes onto Quiver's structured error types
  (`H3StreamError`, `H3GoAway`, `QUICTransportError`, `QUICHandshakeFailed`).

HTTP/3 is HTTPS-only (no cleartext fallback); the transport is QUIC over UDP
and ALPN negotiates the `h3` token directly inside the QUIC handshake.

## Transport Layer

The `Quiver.Transport` behaviour abstracts socket operations with two implementations:

- `Quiver.Transport.SSL` -- TLS sockets with certificate verification via `castore`
- `Quiver.Transport.TCP` -- plain TCP sockets

Sockets are passive by default. Use `activate/1` to switch to `{:active, :once}` mode
for receiving server-initiated frames (HTTP/2 PING, GOAWAY).

For HTTP/3, the transport is QUIC over UDP and is owned by `:quic_h3` itself;
Quiver does not interact with sockets directly for that protocol.

## Supervision Tree

```
Quiver.Supervisor (:rest_for_one)
  |-- Cleanup (GenServer, traps exit to clean persistent_term)
  |-- Registry (pool lookup by origin)
  |-- DynamicSupervisor (pool processes)
        |-- Pool.HTTP1 (per origin, NimblePool)
        |-- Pool.HTTP2 (per origin, coordinator)
        |     |-- Pool.HTTP2.Connection (per connection)
        |-- Pool.HTTP3 (per origin, coordinator)
              |-- Pool.HTTP3.Connection (per connection)
```

The `:rest_for_one` strategy ensures that if the Registry crashes, the
DynamicSupervisor (and all pools) restart too, maintaining registration consistency.

## Configuration

`Quiver.Config` validates all configuration eagerly at supervisor init time using
[Zoi](https://hex.pm/packages/zoi) schema validation. Pool rules support origin
pattern matching with three specificity levels: `:exact` > `:wildcard` > `:default`.

Invalid configuration causes a startup crash rather than runtime surprises.
