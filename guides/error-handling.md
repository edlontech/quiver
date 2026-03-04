# Error Handling

Quiver uses [Splode](https://hex.pm/packages/splode) for structured error classification.
Every error carries a `:class` that tells you how to react.

## Error Classes

| Class | Meaning | Action |
|-------|---------|--------|
| `:transient` | Temporary failure, the same request may succeed on retry | Retry with backoff |
| `:invalid` | Caller-side mistake, the request itself is wrong | Fix the input |
| `:unrecoverable` | Infrastructure broken, won't resolve on its own | Escalate / alert |

## Pattern Matching on Errors

```elixir
case Quiver.new(:get, url) |> Quiver.request(:http_client) do
  {:ok, response} ->
    process(response)

  {:error, %Quiver.Error{class: :transient} = error} ->
    Logger.warning("Transient error: #{Exception.message(error)}")
    retry(url)

  {:error, %Quiver.Error{class: :invalid} = error} ->
    Logger.error("Invalid request: #{Exception.message(error)}")
    {:error, :bad_request}

  {:error, %Quiver.Error{class: :unrecoverable} = error} ->
    Logger.error("Unrecoverable: #{Exception.message(error)}")
    {:error, :service_unavailable}
end
```

You can also match on specific error types:

```elixir
case result do
  {:error, %Quiver.Error.Timeout{}} ->
    # Handle timeout specifically

  {:error, %Quiver.Error.TLSVerificationFailed{host: host}} ->
    Logger.error("Certificate verification failed for #{host}")

  {:error, _} ->
    # Generic fallback
end
```

## Retry Strategies by Class

### Transient errors -- retry with backoff

Transient errors are safe to retry. Use exponential backoff:

```elixir
defp request_with_retry(request, name, retries \\ 3, delay \\ 100)
defp request_with_retry(_request, _name, 0, _delay), do: {:error, :max_retries}

defp request_with_retry(request, name, retries, delay) do
  case Quiver.request(request, name) do
    {:ok, response} ->
      {:ok, response}

    {:error, %Quiver.Error{class: :transient}} ->
      Process.sleep(delay)
      request_with_retry(request, name, retries - 1, delay * 2)

    {:error, _} = error ->
      error
  end
end
```

### Invalid errors -- fix and retry

Invalid errors indicate a problem with the request. Don't retry without changing the input.

### Unrecoverable errors -- escalate

Unrecoverable errors signal infrastructure problems (TLS misconfiguration, protocol
violations). Log them, alert your monitoring system, and investigate.

## Error Reference

### Transient Errors

| Error | Description |
|-------|-------------|
| `Quiver.Error.Timeout` | Connect or receive timeout |
| `Quiver.Error.ConnectionClosed` | Remote peer closed the connection |
| `Quiver.Error.ConnectionRefused` | Connection refused by remote host |
| `Quiver.Error.ConnectionFailed` | Generic connection failure |
| `Quiver.Error.DNSResolutionFailed` | DNS lookup failed for the host |
| `Quiver.Error.CheckoutTimeout` | Pool had no available connection within the timeout |
| `Quiver.Error.PoolStartFailed` | Dynamic pool creation failed |
| `Quiver.Error.StreamClosed` | Operation on a closed HTTP/2 stream |
| `Quiver.Error.MaxConcurrentStreamsReached` | Server's max concurrent streams limit hit |
| `Quiver.Error.StreamError` | Error while consuming a streaming response body |

### Invalid Errors

| Error | Description |
|-------|-------------|
| `Quiver.Error.InvalidScheme` | Unsupported URI scheme |
| `Quiver.Error.MalformedHeaders` | Unparseable HTTP header line |
| `Quiver.Error.InvalidContentLength` | Non-numeric or conflicting content-length |
| `Quiver.Error.InvalidPoolOpts` | Pool options failed validation |
| `Quiver.Error.InvalidPoolRule` | Pool config key not a valid origin pattern |

### Unrecoverable Errors

| Error | Description |
|-------|-------------|
| `Quiver.Error.TLSVerificationFailed` | TLS certificate verification failed |
| `Quiver.Error.TLSHandshakeFailed` | TLS handshake failed (cipher mismatch, protocol error) |
| `Quiver.Error.ProtocolViolation` | Malformed status line, invalid version, garbage bytes |
| `Quiver.Error.GoAway` | Server sent GOAWAY, rejecting streams |
| `Quiver.Error.StreamReset` | Remote peer reset a specific HTTP/2 stream |
| `Quiver.Error.FrameSizeError` | HTTP/2 frame exceeds maximum size |
| `Quiver.Error.CompressionError` | HPACK header decompression failed |
