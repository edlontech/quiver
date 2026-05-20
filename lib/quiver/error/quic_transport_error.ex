defmodule Quiver.Error.QUICTransportError do
  @moduledoc """
  Connection-level error post-handshake (RFC 9000 Section 20 / RFC 9114 Section 8).

  Unrecoverable: the connection is dead and retrying immediately is unlikely
  to help.
  """

  use Splode.Error, fields: [:code, :reason], class: :unrecoverable
  @type t :: Splode.Error.t()

  def message(%{code: code, reason: reason}) do
    "QUIC transport error: code=0x#{Integer.to_string(code, 16)} reason=#{inspect(reason)}"
  end
end
