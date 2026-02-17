defmodule Quiver.Error.Transient do
  @moduledoc """
  Temporary failures where retrying the same request may succeed.
  """

  use Splode.ErrorClass, class: :transient
end

defmodule Quiver.Error.Timeout do
  @moduledoc """
  Connect or receive timeout.
  """

  use Splode.Error, fields: [:message], class: :transient
  @type t :: Splode.Error.t()

  def message(%{message: message}), do: message
end

defmodule Quiver.Error.ConnectionClosed do
  @moduledoc """
  Remote peer closed the connection unexpectedly.
  """

  use Splode.Error, fields: [:message], class: :transient
  @type t :: Splode.Error.t()

  def message(%{message: message}), do: message
end

defmodule Quiver.Error.ConnectionRefused do
  @moduledoc """
  Connection refused by remote host.
  """

  use Splode.Error, fields: [:message], class: :transient
  @type t :: Splode.Error.t()

  def message(%{message: message}), do: message
end

defmodule Quiver.Error.ConnectionFailed do
  @moduledoc """
  Generic connection failure not covered by a more specific error type.
  """

  use Splode.Error, fields: [:message], class: :transient
  @type t :: Splode.Error.t()

  def message(%{message: message}), do: message
end

defmodule Quiver.Error.DNSResolutionFailed do
  @moduledoc """
  DNS resolution failed for the given host.
  """

  use Splode.Error, fields: [:host], class: :transient
  @type t :: Splode.Error.t()

  def message(%{host: host}), do: "DNS resolution failed for #{host}"
end

defmodule Quiver.Error.CheckoutTimeout do
  @moduledoc """
  Pool checkout timed out waiting for an available connection.
  """

  use Splode.Error, fields: [:origin, :timeout], class: :transient
  @type t :: Splode.Error.t()

  def message(%{origin: origin, timeout: timeout}) do
    "checkout timeout after #{timeout}ms for #{origin}"
  end
end

defmodule Quiver.Error.PoolStartFailed do
  @moduledoc """
  Dynamic pool creation failed.
  """

  use Splode.Error, fields: [:origin, :reason], class: :transient
  @type t :: Splode.Error.t()

  def message(%{origin: {scheme, host, port}, reason: reason}) do
    "pool start failed for #{scheme}://#{host}:#{port}: #{inspect(reason)}"
  end
end

defmodule Quiver.Error.StreamClosed do
  @moduledoc """
  Attempted operation on a closed or non-existent HTTP/2 stream.
  """

  use Splode.Error, fields: [:stream_id], class: :transient
  @type t :: Splode.Error.t()

  def message(%{stream_id: id}), do: "stream #{id} is closed"
end

defmodule Quiver.Error.MaxConcurrentStreamsReached do
  @moduledoc """
  Cannot open a new stream; server's max concurrent streams limit reached.
  """

  use Splode.Error, fields: [:max], class: :transient
  @type t :: Splode.Error.t()

  def message(%{max: max}), do: "max concurrent streams reached (#{max})"
end

defmodule Quiver.Error.StreamError do
  @moduledoc """
  Error raised when consuming a streaming response body.
  """

  use Splode.Error, fields: [:reason], class: :transient
  @type t :: Splode.Error.t()

  def message(%{reason: reason}), do: "stream error: #{inspect(reason)}"
end
