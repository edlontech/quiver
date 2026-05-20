defmodule Quiver.Error.H3StreamError do
  @moduledoc """
  Peer reset a request stream with RESET_STREAM (RFC 9114 Section 4.1).
  """

  alias Quiver.Error.H3Codes

  use Splode.Error, fields: [:stream_id, :code], class: :transient
  @type t :: Splode.Error.t()

  def message(%{stream_id: id, code: code}) do
    name =
      case H3Codes.decode(code) do
        {:unknown, _} -> :unknown
        atom -> atom
      end

    "h3 stream #{id} reset: code=0x#{Integer.to_string(code, 16)} (#{name})"
  end
end
