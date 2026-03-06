defmodule Quiver.Utils do
  @moduledoc false

  @doc """
  Downcases all header names.

  HTTP header field names are case-insensitive (RFC 9110 Section 5.1).
  HTTP/2 additionally requires lowercase header names (RFC 9113 Section 8.2).
  """
  @spec normalize_headers([{String.t(), String.t()}]) :: [{String.t(), String.t()}]
  def normalize_headers(headers) when is_list(headers) do
    Enum.map(headers, fn {name, value} -> {String.downcase(name), value} end)
  end
end
