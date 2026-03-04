# Quiver

A fast, resilient HTTP client for Elixir with built-in connection pooling,
HTTP/2 multiplexing, and streaming support.

<!-- badges placeholder -->

## Features

- **HTTP/1.1 and HTTP/2** -- automatic protocol handling with TLS+ALPN
- **Connection pooling** -- NimblePool for HTTP/1, GenStateMachine coordinator for HTTP/2
- **Streaming responses** -- lazy body streams for large payloads and SSE
- **Origin-based routing** -- exact, wildcard, and default pool rules per origin
- **Structured errors** -- three error classes (transient, invalid, unrecoverable)
- **Telemetry** -- request spans, connection lifecycle, and pool queue depth events
- **Supervised** -- pools start lazily and live under your application's supervision tree

## Installation

Add `quiver` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:quiver, "~> 0.1.0"}
  ]
end
```

## Quick Start

Add Quiver to your supervision tree:

```elixir
children = [
  {Quiver.Supervisor, pools: %{default: [size: 10]}}
]

Supervisor.start_link(children, strategy: :one_for_one)
```

Make requests -- no need to pass a name, Quiver uses `Quiver.Pool` by default:

```elixir
# GET request
{:ok, %Quiver.Response{status: 200, body: body}} =
  Quiver.new(:get, "https://httpbin.org/get")
  |> Quiver.request()

# POST with headers and body
{:ok, %Quiver.Response{status: 200}} =
  Quiver.new(:post, "https://httpbin.org/post")
  |> Quiver.header("content-type", "application/json")
  |> Quiver.body(~s({"key": "value"}))
  |> Quiver.request()
```

Stream large responses:

```elixir
{:ok, %Quiver.StreamResponse{status: 200, body: body_stream}} =
  Quiver.new(:get, "https://httpbin.org/stream/100")
  |> Quiver.stream_request()

body_stream
|> Stream.each(&IO.write/1)
|> Stream.run()
```

### Custom supervisor name

If you need multiple Quiver instances, pass a `:name` option:

```elixir
# Supervision tree
children = [
  {Quiver.Supervisor, name: :internal_client, pools: %{default: [size: 20]}},
  {Quiver.Supervisor, name: :external_client, pools: %{default: [size: 5]}}
]

# Requests
Quiver.new(:get, "https://internal.api/data")
|> Quiver.request(name: :internal_client)
```

## Pool Configuration

Route origins to pools with different settings:

```elixir
pools = %{
  "https://api.example.com" => [size: 50],
  "https://*.internal.io"   => [size: 20],
  default:                     [size: 5]
}

{Quiver.Supervisor, pools: pools}
```

Rules match by specificity: exact > wildcard > default.

By default, Quiver auto-detects the HTTP protocol via TLS ALPN negotiation.
To force a specific protocol per origin:

```elixir
pools = %{
  "https://http2-only.example.com" => [size: 10, protocol: :http2],
  "https://legacy.example.com"     => [size: 10, protocol: :http1],
  default:                            [size: 5]
}
```

## Documentation

- [Getting Started](guides/getting-started.md)
- [Architecture](guides/architecture.md)
- [Error Handling](guides/error-handling.md)
- [Telemetry](guides/telemetry.md)

Full API documentation is available on [HexDocs](https://hexdocs.pm/quiver).

## License

MIT -- see [LICENSE](LICENSE) for details.
