defmodule Quiver.StreamResponse do
  @moduledoc """
  Response struct for streaming HTTP requests.

  Contains eagerly-received `status` and `headers`, plus a lazy `body`
  stream that yields binary chunks as the caller enumerates it.
  """

  use TypedStruct

  typedstruct do
    field(:status, non_neg_integer(), enforce: true)
    field(:headers, [{String.t(), String.t()}], enforce: true)
    field(:body, Enumerable.t(), enforce: true)
    field(:ref, reference(), enforce: true)
  end
end
