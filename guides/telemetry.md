# Telemetry

Quiver emits [Telemetry](https://hex.pm/packages/telemetry) events for requests,
connections, and pool operations. All events use the `[:quiver, ...]` prefix.

## Event Reference

### Request Span

Wraps the full lifecycle of a single HTTP request.

| Event | Measurements | Metadata |
|-------|-------------|----------|
| `[:quiver, :request, :start]` | `system_time` | `request`, `origin`, `name` |
| `[:quiver, :request, :stop]` | `duration` | `request`, `response`, `origin`, `name` |
| `[:quiver, :request, :exception]` | `duration` | `request`, `kind`, `reason`, `stacktrace`, `origin`, `name` |

- **`request`** -- the `%Quiver.Request{}` struct
- **`response`** -- the `%Quiver.Response{}` struct (only on `:stop`)
- **`origin`** -- `{scheme, host, port}` tuple
- **`name`** -- the Quiver instance atom name
- **`duration`** -- elapsed time in native units (use `System.convert_time_unit/3`)

### Connection Span

Emitted when a fresh connection is established (not on reuse).

| Event | Measurements | Metadata |
|-------|-------------|----------|
| `[:quiver, :conn, :start]` | `system_time` | `origin`, `scheme` |
| `[:quiver, :conn, :stop]` | `duration` | `origin`, `scheme` |

### Connection Close

Standalone event fired when a connection is evicted from the pool.

| Event | Measurements | Metadata |
|-------|-------------|----------|
| `[:quiver, :conn, :close]` | `system_time` | `origin`, `reason` |

### Pool Queue

Emitted when callers are queued waiting for a connection.

| Event | Measurements | Metadata |
|-------|-------------|----------|
| `[:quiver, :pool, :queue]` | `queue_length` | `origin`, `name` |

## Example Handler

Attach handlers in your application startup:

```elixir
defmodule MyApp.QuiverTelemetry do
  require Logger

  def setup do
    events = [
      [:quiver, :request, :stop],
      [:quiver, :request, :exception],
      [:quiver, :conn, :close],
      [:quiver, :pool, :queue]
    ]

    :telemetry.attach_many(
      "myapp-quiver-handler",
      events,
      &__MODULE__.handle_event/4,
      nil
    )
  end

  def handle_event([:quiver, :request, :stop], %{duration: duration}, metadata, _config) do
    ms = System.convert_time_unit(duration, :native, :millisecond)
    {scheme, host, port} = metadata.origin

    Logger.info("#{scheme}://#{host}:#{port} responded in #{ms}ms")
  end

  def handle_event([:quiver, :request, :exception], %{duration: duration}, metadata, _config) do
    ms = System.convert_time_unit(duration, :native, :millisecond)

    Logger.error(
      "Request failed after #{ms}ms: #{inspect(metadata.reason)}"
    )
  end

  def handle_event([:quiver, :conn, :close], _measurements, metadata, _config) do
    {scheme, host, port} = metadata.origin

    Logger.debug(
      "Connection closed for #{scheme}://#{host}:#{port}: #{metadata.reason}"
    )
  end

  def handle_event([:quiver, :pool, :queue], %{queue_length: len}, metadata, _config) do
    if len > 10 do
      Logger.warning("Pool queue depth #{len} for #{inspect(metadata.origin)}")
    end
  end
end
```

Call `MyApp.QuiverTelemetry.setup()` in your `Application.start/2`.

## Integration with Metrics Libraries

Telemetry events integrate with common metrics libraries:

### With Telemetry.Metrics

```elixir
defmodule MyApp.Metrics do
  import Telemetry.Metrics

  def metrics do
    [
      summary("quiver.request.duration",
        unit: {:native, :millisecond},
        tags: [:origin]
      ),
      counter("quiver.request.exception.duration",
        tags: [:origin]
      ),
      last_value("quiver.pool.queue.queue_length",
        tags: [:origin]
      )
    ]
  end
end
```

These metrics definitions work with reporters like
`TelemetryMetricsPrometheus`, `TelemetryMetricsStatsd`, or the
built-in `ConsoleReporter`.
