defmodule Quiver.Response do
  @moduledoc """
  HTTP response data container.
  """

  @enforce_keys [:status]
  defstruct [:status, headers: [], body: nil, trailers: []]

  @type t :: %__MODULE__{
          status: non_neg_integer(),
          headers: [{String.t(), String.t()}],
          body: iodata() | nil,
          trailers: [{String.t(), String.t()}]
        }
end
