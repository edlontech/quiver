defmodule Quiver.Error.GoAwayUnprocessed do
  @moduledoc """
  Request was not processed by the server before GOAWAY.

  The stream ID exceeds the server's `last_stream_id`, meaning the server
  never began processing this request. Safe to retry on a new connection.
  """

  use Splode.Error, fields: [:last_stream_id, :error_code, :debug_data], class: :transient
  @type t :: Splode.Error.t()

  def message(%{last_stream_id: id, error_code: code}) do
    "GOAWAY: request unprocessed (stream > last_stream_id=#{id}, error_code=#{code})"
  end
end
