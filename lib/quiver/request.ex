defmodule Quiver.Request do
  @moduledoc """
  HTTP request data container.
  """

  @enforce_keys [:method, :url]
  defstruct [:method, :url, headers: [], body: nil]

  @type t :: %__MODULE__{
          method: atom(),
          url: URI.t(),
          headers: [{String.t(), String.t()}],
          body: iodata() | nil | {:stream, Enumerable.t()}
        }
end
