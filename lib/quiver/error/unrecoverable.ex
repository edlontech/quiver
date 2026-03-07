defmodule Quiver.Error.Unrecoverable do
  @moduledoc """
  Infrastructure failures that will not resolve without intervention.
  """

  use Splode.ErrorClass, class: :unrecoverable
end

defmodule Quiver.Error.TLSVerificationFailed do
  @moduledoc """
  TLS certificate verification failed for the given host.
  """

  use Splode.Error, fields: [:host], class: :unrecoverable
  @type t :: Splode.Error.t()

  def message(%{host: host}), do: "TLS certificate verification failed for #{host}"
end

defmodule Quiver.Error.TLSHandshakeFailed do
  @moduledoc """
  TLS handshake failed due to cipher mismatch, protocol error, etc.
  """

  use Splode.Error, fields: [:reason], class: :unrecoverable
  @type t :: Splode.Error.t()

  def message(%{reason: reason}), do: "TLS handshake failed: #{inspect(reason)}"
end

defmodule Quiver.Error.ProtocolViolation do
  @moduledoc """
  HTTP protocol violation -- malformed status line, invalid version, garbage bytes.
  """

  use Splode.Error, fields: [:message], class: :unrecoverable
  @type t :: Splode.Error.t()

  def message(%{message: message}), do: message
end

defmodule Quiver.Error.GoAway do
  @moduledoc """
  Connection-level GOAWAY signal -- the connection is shutting down.

  This is an unrecoverable error representing the GOAWAY event itself.
  For streams that were never processed by the server (stream ID above
  `last_stream_id`), see `Quiver.Error.GoAwayUnprocessed` which is
  transient and safe to retry on a new connection.
  """

  use Splode.Error, fields: [:last_stream_id, :error_code, :debug_data], class: :unrecoverable
  @type t :: Splode.Error.t()

  def message(%{last_stream_id: id, error_code: code}) do
    "GOAWAY received: last_stream_id=#{id}, error_code=#{code}"
  end
end

defmodule Quiver.Error.StreamReset do
  @moduledoc """
  Remote peer reset a specific HTTP/2 stream.
  """

  use Splode.Error, fields: [:stream_id, :error_code], class: :unrecoverable
  @type t :: Splode.Error.t()

  def message(%{stream_id: id, error_code: code}) do
    "stream #{id} reset with error code #{code}"
  end
end

defmodule Quiver.Error.FrameSizeError do
  @moduledoc """
  HTTP/2 frame exceeds maximum allowed size or has invalid length.
  """

  use Splode.Error, fields: [:message], class: :unrecoverable
  @type t :: Splode.Error.t()

  def message(%{message: message}), do: message
end

defmodule Quiver.Error.CompressionError do
  @moduledoc """
  HPACK decompression failed.
  """

  use Splode.Error, fields: [:message], class: :unrecoverable
  @type t :: Splode.Error.t()

  def message(%{message: message}), do: message
end
