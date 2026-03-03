# Getting Started

## Installation

Add `quiver` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:quiver, "~> 0.1.0"}
  ]
end
```

## Starting a Quiver Instance

Quiver runs as a supervised process tree. Add it to your application's supervision tree:

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Quiver.Supervisor, name: :http_client, pools: %{default: []}}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
```

The `:name` option must be a compile-time atom (e.g. `:http_client`). Avoid creating
names from user input -- Elixir atoms are never garbage collected.

## Making Requests

Build requests with `Quiver.new/2`, add headers or body with `Quiver.header/3` and
`Quiver.body/2`, then execute with `Quiver.request/3`:

```elixir
# Simple GET
{:ok, %Quiver.Response{status: 200, body: body}} =
  Quiver.new(:get, "https://httpbin.org/get")
  |> Quiver.request(:http_client)

# POST with JSON body
{:ok, %Quiver.Response{status: 200}} =
  Quiver.new(:post, "https://httpbin.org/post")
  |> Quiver.header("content-type", "application/json")
  |> Quiver.body(~s({"key": "value"}))
  |> Quiver.request(:http_client)

# Custom headers
{:ok, response} =
  Quiver.new(:get, "https://api.example.com/data")
  |> Quiver.header("authorization", "Bearer my-token")
  |> Quiver.header("accept", "application/json")
  |> Quiver.request(:http_client)
```

## Streaming Responses

For large responses or server-sent events, use `Quiver.stream_request/3`. It returns
status and headers eagerly, with a lazy body stream:

```elixir
{:ok, %Quiver.StreamResponse{status: 200, headers: headers, body: body_stream}} =
  Quiver.new(:get, "https://httpbin.org/stream/100")
  |> Quiver.stream_request(:http_client)

# Consume chunks lazily
body_stream
|> Stream.each(fn chunk -> IO.write(chunk) end)
|> Stream.run()
```

The body stream holds a connection from the pool until fully consumed or halted.
Always consume the stream to return the connection to the pool.

## Pool Configuration

### Default pool

The simplest configuration uses a single default pool for all origins:

```elixir
{Quiver.Supervisor, name: :http_client, pools: %{default: [size: 20]}}
```

### Per-origin pools

Route specific origins to pools with custom settings:

```elixir
pools = %{
  # Exact origin match
  "https://api.example.com" => [size: 50, protocol: :http2],

  # Wildcard: matches any subdomain of example.com
  "https://*.example.com" => [size: 10],

  # Fallback for everything else
  default: [size: 5]
}

{Quiver.Supervisor, name: :http_client, pools: pools}
```

Rules are matched by specificity: exact > wildcard > default.

### Pool options

| Option | Default | Description |
|--------|---------|-------------|
| `:size` | 10 | Maximum connections (HTTP/1) or concurrent streams per connection (HTTP/2) |
| `:protocol` | `:http1` | Force `:http1` or `:http2` |
| `:checkout_timeout` | 5000 | Max ms to wait for an available connection |
| `:idle_timeout` | 30000 | Close connections idle longer than this |
| `:ping_interval` | 5000 | HTTP/2 PING frame interval |
| `:max_connections` | 5 | Max HTTP/2 connections per origin |
| `:transport_opts` | `[]` | Options passed to the transport layer |

## Error Handling

Quiver returns tagged tuples. Errors are classified by recoverability:

```elixir
case Quiver.new(:get, url) |> Quiver.request(:http_client) do
  {:ok, %Quiver.Response{status: status, body: body}} ->
    handle_success(status, body)

  {:error, %Quiver.Error{class: :transient}} ->
    # Retry-safe: timeouts, connection closed, DNS failures
    retry_later()

  {:error, %Quiver.Error{class: :invalid}} ->
    # Fix the request: bad scheme, malformed headers
    log_caller_error()

  {:error, %Quiver.Error{class: :unrecoverable}} ->
    # Infrastructure issue: TLS failures, protocol violations
    escalate()
end
```

See the [Error Handling guide](error-handling.md) for the full error reference.
