defmodule Quiver.Error.H3DatagramsDisabled do
  @moduledoc """
  HTTP/3 datagrams (RFC 9297) are not negotiated on this connection.

  Transient: a different connection or origin may successfully negotiate.
  Returned when either the local side disabled `:h3_datagram_enabled` or
  the peer did not advertise SETTINGS_H3_DATAGRAM = 1 with a non-zero
  QUIC `max_datagram_frame_size`.
  """

  use Splode.Error, fields: [:origin], class: :transient
  @type t :: Splode.Error.t()

  def message(%{origin: origin}) do
    "HTTP/3 datagrams are not negotiated on this connection (#{inspect(origin)})"
  end
end
