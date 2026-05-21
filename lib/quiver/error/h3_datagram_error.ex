defmodule Quiver.Error.H3DatagramError do
  @moduledoc """
  Datagram send failed at the QUIC or HTTP/3 layer.

  `reason` is one of:

  - `:unknown_stream` -- the bound H/3 stream is no longer tracked
    (typically a benign send-after-close race; class `:transient`)
  - `:too_large` -- payload exceeded the peer's advertised
    `max_datagram_size`; caller must shrink (class overridden to
    `:invalid` by the mapper)
  - `:too_large_for_path` -- current path MTU forbids this size
    (class `:transient`)
  - `:congestion_limited` -- sender's congestion controller is closed
    (class `:transient`)
  - Other atom -- forwarded from `:quic_h3`; class `:transient`
  """

  use Splode.Error, fields: [:reason], class: :transient
  @type t :: Splode.Error.t()

  @type reason ::
          :unknown_stream
          | :too_large
          | :too_large_for_path
          | :congestion_limited
          | atom()

  def message(%{reason: reason}), do: "HTTP/3 datagram send failed: #{inspect(reason)}"
end
