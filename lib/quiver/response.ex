defmodule Quiver.Response do
  @moduledoc """
  HTTP response data container.
  """

  use TypedStruct

  typedstruct do
    field(:status, non_neg_integer(), enforce: true)
    field(:headers, [{String.t(), String.t()}], default: [])
    field(:body, iodata() | nil, default: nil)
  end
end
