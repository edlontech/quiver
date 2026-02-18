defmodule Quiver.Conn.HTTP1.Request do
  @moduledoc """
  HTTP/1.1 request line and header serialization.
  """

  @spec encode(atom(), String.t(), [{String.t(), String.t()}], iodata() | nil) :: iodata()
  def encode(method, path, headers, body) do
    method_str = method |> Atom.to_string() |> String.upcase()
    request_line = [method_str, " ", path, " HTTP/1.1\r\n"]
    headers = maybe_add_content_length(headers, body)
    header_lines = Enum.map(headers, fn {name, value} -> [name, ": ", value, "\r\n"] end)

    case body do
      nil -> [request_line, header_lines, "\r\n"]
      body -> [request_line, header_lines, "\r\n", body]
    end
  end

  defp maybe_add_content_length(headers, nil), do: headers

  defp maybe_add_content_length(headers, body) do
    if has_content_length?(headers) do
      headers
    else
      headers ++ [{"content-length", Integer.to_string(IO.iodata_length(body))}]
    end
  end

  defp has_content_length?(headers) do
    Enum.any?(headers, fn {name, _} ->
      String.downcase(name) == "content-length"
    end)
  end
end
