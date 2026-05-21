defmodule Quiver.Telemetry do
  @moduledoc """
  Telemetry event definitions and helpers for Quiver.

  ## Request Span

  - `[:quiver, :request, :start]` -- measurements: `system_time` | metadata: `request, origin, name`
  - `[:quiver, :request, :stop]` -- measurements: `duration` | metadata: `request, response, origin, name`
  - `[:quiver, :request, :exception]` -- measurements: `duration` | metadata: `request, kind, reason, stacktrace, origin, name`

  ## Connection Span (fresh connections only)

  - `[:quiver, :conn, :start]` -- measurements: `system_time` | metadata: `origin, scheme`
  - `[:quiver, :conn, :stop]` -- measurements: `duration` | metadata: `origin, scheme`

  ## Connection Close (standalone, fires on eviction)

  - `[:quiver, :conn, :close]` -- measurements: `system_time` | metadata: `origin, reason`

  ## Pool Queue

  - `[:quiver, :pool, :queue]` -- measurements: `queue_length` | metadata: `origin, name`

  ## HTTP/3 Connection

  - `[:quiver, :connection, :http3, :start]` -- measurements: `system_time` | metadata: `origin, pool_pid`
  - `[:quiver, :connection, :http3, :stop]` -- measurements: `duration` | metadata: `origin, peer_max_streams`
  - `[:quiver, :connection, :http3, :exception]` -- measurements: `duration` | metadata: `origin, reason, kind`
  - `[:quiver, :connection, :http3, :draining]` -- measurements: `system_time` | metadata: `origin, last_stream_id, error_code`

  ## HTTP/3 Datagrams & Channels

  - `[:quiver, :connection, :http3, :datagram, :sent]` -- measurements: `bytes` | metadata: `origin, stream_id`
  - `[:quiver, :connection, :http3, :datagram, :received]` -- measurements: `bytes` | metadata: `origin, stream_id`
  - `[:quiver, :connection, :http3, :datagram, :send_failed]` -- measurements: `system_time` | metadata: `origin, stream_id, reason`
  - `[:quiver, :connection, :http3, :datagram, :dropped]` -- measurements: `system_time` | metadata: `origin, stream_id, reason`
  - `[:quiver, :connection, :http3, :channel, :start]` -- measurements: `system_time` | metadata: `origin, method, path`
  - `[:quiver, :connection, :http3, :channel, :stop]` -- measurements: `duration` | metadata: `origin, close_reason`
  - `[:quiver, :connection, :http3, :channel, :exception]` -- measurements: `duration` | metadata: `origin, kind, reason`
  """

  @doc false
  @spec request_event_prefix() :: [atom()]
  def request_event_prefix, do: [:quiver, :request]

  @doc false
  @spec conn_event_prefix() :: [atom()]
  def conn_event_prefix, do: [:quiver, :conn]

  @doc false
  @spec conn_close_event() :: [atom()]
  def conn_close_event, do: [:quiver, :conn, :close]

  @doc false
  @spec pool_queue_event() :: [atom()]
  def pool_queue_event, do: [:quiver, :pool, :queue]

  @doc false
  @spec connection_http3_event_prefix() :: [atom()]
  def connection_http3_event_prefix, do: [:quiver, :connection, :http3]

  @doc false
  @spec connection_http3_datagram_event_prefix() :: [atom()]
  def connection_http3_datagram_event_prefix, do: [:quiver, :connection, :http3, :datagram]

  @doc false
  @spec connection_http3_channel_event_prefix() :: [atom()]
  def connection_http3_channel_event_prefix, do: [:quiver, :connection, :http3, :channel]

  @doc false
  @spec span([atom()], map(), (-> {result, map()})) :: result when result: term()
  def span(event_prefix, metadata, fun) do
    :telemetry.span(event_prefix, metadata, fun)
  end

  @doc false
  @spec event([atom()], map(), map()) :: :ok
  def event(event_name, measurements, metadata) do
    :telemetry.execute(event_name, measurements, metadata)
  end
end
