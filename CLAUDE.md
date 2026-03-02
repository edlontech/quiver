# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Skills

When working on Elixir (.ex/.exs) files, invoke the `elixir-thinking` skill before exploring code. For OTP-specific work (GenServer, Supervisor, GenStateMachine), also invoke `otp-thinking`.

## Commands

```bash
# Quality (full suite: credo, dialyzer, tests, doctor, etc.)
mix check

# Tests
mix test                       # Unit tests (excludes integration)
mix test test/path_test.exs    # Single file
mix test test/path_test.exs:42 # Single test by line
mix test.integration           # Integration tests only

# Code quality individually
mix format                     # Format code
mix credo --strict             # Lint
mix dialyzer                   # Type checking

# Benchmarks
mix bench.vs_finch             # Compare against Finch
mix bench.all                  # All benchmarks
```

## Architecture

Quiver is an HTTP client library supporting HTTP/1.1 and HTTP/2 with connection pooling.

### Request flow

```
Quiver.request/3 → Pool.Manager → Pool (HTTP1 or HTTP2) → Conn → Transport → Server
```

**Manager** (`pool/manager.ex`) is stateless. Hot path looks up existing pools via `Registry`; cold path starts new ones via `DynamicSupervisor`. Pools self-register in `:persistent_term` for protocol detection.

### Pool layer

- **HTTP/1** (`pool/http1.ex`) - NimblePool. Lazy connection creation in caller's process. Stats in ETS.
- **HTTP/2** (`pool/http2.ex`) - GenStateMachine coordinator per origin (`:idle`/`:connected` states). Routes callers to available stream slots across multiple connections.
  - **Connection** (`pool/http2/connection.ex`) - GenStateMachine per connection (`:connected`/`:draining`). Owns the HTTP/2 connection, manages multiplexing, handles GOAWAY drain.
  - Two-phase caller model: caller → coordinator call → coordinator forwards `{:forward_request, from, ...}` to worker → worker replies directly to original caller's `from`.

Both implement `Quiver.Pool` behaviour (`request/6`, `stats/1`).

### Connection layer

`Quiver.Conn` behaviour with two implementations:
- **HTTP1** (`conn/http1.ex`) - Synchronous request/response. Sub-modules: `HTTP1.Parse`, `HTTP1.Request`.
- **HTTP2** (`conn/http2.ex`) - Stateless data struct (not a process). TLS+ALPN only (no h2c). HPACK via `hpax`, frame codec in `HTTP2.Frame`.

### Transport layer

`Quiver.Transport` behaviour with `SSL` and `TCP` implementations. Sockets are passive by default; use `activate/1` for `{:active, :once}`.

### Error handling

Splode-based structured errors with three classes: `:transient` (retry), `:invalid` (fix input), `:unrecoverable` (escalate). Defined in `error/` subdirectory.

### Configuration

`Quiver.Config` uses Zoi for schema validation. Pool rules support origin pattern matching (`:exact` > `:wildcard` > `:default`). Config validated eagerly in `init/1` - always `{:stop, reason}` on failure.

### Supervision tree

`Quiver.Supervisor` (`:rest_for_one`): Cleanup → Registry → DynamicSupervisor.

### Telemetry

Request and connection spans under `[:quiver, ...]` prefix. See `telemetry.ex` for event names and metadata.

## Key patterns

- GenStateMachine sweep timers use bare atom `:sweep_queue` (not tuple). Handler must exist in ALL states where timer can fire.
- Stream cancellation: always send `{:stream_done}` and call `maybe_stop_draining` even on cancel error.
- Idle enter callback: call `sweep_expired(data)` to flush expired callers immediately.
- Test infrastructure: `test/support/` has `TestServer` (Bandit-based), `Certs`, `SSLListener`, `TCPListener`. Integration tests use `Quiver.TestCase.Integration`.
- Test compile paths: `:test` env adds `test/support/`, `:dev` env adds `bench/support/`.

## Style

- Max line length: 120 characters
- Credo strict mode enabled
- Recode handles alias expansion and ordering
- No trailing whitespace
- No superfluous in-function comments
