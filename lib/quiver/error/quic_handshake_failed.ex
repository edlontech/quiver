defmodule Quiver.Error.QUICHandshakeFailed do
  @moduledoc """
  QUIC or HTTP/3 connection handshake failed before reaching `:connected`.

  Transient because the failure may be transport or peer related and a
  retry on a new connection can succeed.
  """

  use Splode.Error, fields: [:origin, :reason], class: :transient
  @type t :: Splode.Error.t()

  def message(%{origin: {scheme, host, port}, reason: reason}) do
    "QUIC handshake failed for #{scheme}://#{host}:#{port}: #{inspect(reason)}"
  end
end
