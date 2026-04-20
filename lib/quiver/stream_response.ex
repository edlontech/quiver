defmodule Quiver.StreamResponse do
  @moduledoc """
  Response struct for streaming HTTP requests.

  Contains eagerly-received `status` and `headers`, plus a lazy `body`
  stream that yields binary chunks as the caller enumerates it.

  The `ref` field is an opaque internal handle used for stream
  coordination. Callers should not depend on its value.
  """

  @enforce_keys [:status, :headers, :body, :ref]
  defstruct [:status, :headers, :body, :ref, trailers: []]

  @type t :: %__MODULE__{
          status: non_neg_integer(),
          headers: [{String.t(), String.t()}],
          body: Enumerable.t(),
          trailers: [{String.t(), String.t()}],
          ref: reference()
        }
end
