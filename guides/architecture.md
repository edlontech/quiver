# Architecture

Quiver is organized in four layers: Client API, Pool, Connection, and Transport.
Each layer has a clear responsibility and communicates with the layer below through
well-defined interfaces.

## Request Flow

```
Quiver.request/3
  |> Pool.Manager.get_pool/2       (stateless lookup / lazy start)
  |> Pool.request/6                (HTTP1 or HTTP2 pool)
  |> Conn.request/6                (wire protocol)
  |> Transport.send/recv           (SSL or TCP)
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
`{PoolModule, pid} => true` on init. The manager checks both keys to
determine whether to call `Pool.HTTP1` or `Pool.HTTP2`.

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

## Transport Layer

The `Quiver.Transport` behaviour abstracts socket operations with two implementations:

- `Quiver.Transport.SSL` -- TLS sockets with certificate verification via `castore`
- `Quiver.Transport.TCP` -- plain TCP sockets

Sockets are passive by default. Use `activate/1` to switch to `{:active, :once}` mode
for receiving server-initiated frames (HTTP/2 PING, GOAWAY).

## Supervision Tree

```
Quiver.Supervisor (:rest_for_one)
  |-- Cleanup (GenServer, traps exit to clean persistent_term)
  |-- Registry (pool lookup by origin)
  |-- DynamicSupervisor (pool processes)
        |-- Pool.HTTP1 (per origin, NimblePool)
        |-- Pool.HTTP2 (per origin, coordinator)
              |-- Pool.HTTP2.Connection (per connection)
```

The `:rest_for_one` strategy ensures that if the Registry crashes, the
DynamicSupervisor (and all pools) restart too, maintaining registration consistency.

## Configuration

`Quiver.Config` validates all configuration eagerly at supervisor init time using
[Zoi](https://hex.pm/packages/zoi) schema validation. Pool rules support origin
pattern matching with three specificity levels: `:exact` > `:wildcard` > `:default`.

Invalid configuration causes a startup crash rather than runtime surprises.
