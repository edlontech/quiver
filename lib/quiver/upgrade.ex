defmodule Quiver.Upgrade do
  @moduledoc """
  Represents a completed HTTP 101 Switching Protocols upgrade.

  Contains the response headers from the 101 response and the raw
  transport socket for the caller to use with the upgraded protocol.
  """

  use TypedStruct

  typedstruct do
    field(:status, 101, default: 101)
    field(:headers, [{String.t(), String.t()}], default: [])
    field(:transport, Quiver.Transport.t(), enforce: true)
    field(:transport_mod, module(), enforce: true)
  end
end
