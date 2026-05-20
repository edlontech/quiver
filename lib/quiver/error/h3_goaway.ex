defmodule Quiver.Error.H3GoAway do
  @moduledoc """
  Request was not processed by the peer before GOAWAY (RFC 9114 Section 5.2).

  Transient: the request can be safely retried on a fresh connection.
  """

  use Splode.Error,
    fields: [:goaway_id, :stream_id, :unprocessed_stream],
    class: :transient

  @type t :: Splode.Error.t()

  def message(%{goaway_id: gid, stream_id: sid}) do
    "h3 stream #{sid} not processed by peer (GOAWAY id=#{gid}); safe to retry"
  end
end
