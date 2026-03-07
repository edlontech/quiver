defmodule Quiver.Request do
  @moduledoc """
  HTTP request data container.
  """

  use TypedStruct

  typedstruct do
    field(:method, atom(), enforce: true)
    field(:url, URI.t(), enforce: true)
    field(:headers, [{String.t(), String.t()}], default: [])
    field(:body, iodata() | nil | {:stream, Enumerable.t()}, default: nil)
  end
end
