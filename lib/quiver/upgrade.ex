defmodule Quiver.Upgrade do
  @moduledoc """
  Represents a completed HTTP 101 Switching Protocols upgrade.

  Contains the response headers from the 101 response and the raw
  transport socket for the caller to use with the upgraded protocol.
  """

  @enforce_keys [:transport, :transport_mod]
  defstruct status: 101,
            headers: [],
            transport: nil,
            transport_mod: nil

  @type t :: %__MODULE__{
          status: 101,
          headers: [{String.t(), String.t()}],
          transport: Quiver.Transport.t(),
          transport_mod: module()
        }
end
