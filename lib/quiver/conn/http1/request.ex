defmodule Quiver.Conn.HTTP1.Request do
  @moduledoc """
  HTTP/1.1 request line and header serialization.
  """

  @doc false
  @spec encode(atom(), String.t(), [{String.t(), String.t()}], iodata() | nil | :stream) ::
          iodata()
  def encode(method, path, headers, :stream) do
    method_str = method |> Atom.to_string() |> String.upcase()
    request_line = [method_str, " ", path, " HTTP/1.1\r\n"]
    headers = Quiver.Utils.normalize_headers(headers)
    headers = ensure_chunked_encoding(headers)
    header_lines = Enum.map(headers, fn {name, value} -> [name, ": ", value, "\r\n"] end)
    [request_line, header_lines, "\r\n"]
  end

  def encode(method, path, headers, body) do
    method_str = method |> Atom.to_string() |> String.upcase()
    request_line = [method_str, " ", path, " HTTP/1.1\r\n"]
    headers = Quiver.Utils.normalize_headers(headers)
    headers = maybe_add_content_length(headers, body)
    header_lines = Enum.map(headers, fn {name, value} -> [name, ": ", value, "\r\n"] end)

    case body do
      nil -> [request_line, header_lines, "\r\n"]
      body -> [request_line, header_lines, "\r\n", body]
    end
  end

  @doc false
  @spec encode_chunk(iodata()) :: iodata()
  def encode_chunk(data) do
    size = IO.iodata_length(data)
    [Integer.to_string(size, 16), "\r\n", data, "\r\n"]
  end

  @doc false
  @spec encode_last_chunk() :: binary()
  def encode_last_chunk do
    "0\r\n\r\n"
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
      name == "content-length"
    end)
  end

  defp ensure_chunked_encoding(headers) do
    if has_transfer_encoding?(headers) do
      headers
    else
      headers ++ [{"transfer-encoding", "chunked"}]
    end
  end

  defp has_transfer_encoding?(headers) do
    Enum.any?(headers, fn {name, _} -> name == "transfer-encoding" end)
  end
end
