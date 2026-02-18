defmodule Quiver.Conn.HTTP1.Parse do
  @moduledoc """
  Incremental HTTP/1.1 response parser.

  Operates as a state machine. Feed bytes via `parse/2`, get back
  parsed response fragments, updated state, and unconsumed bytes.
  """

  alias Quiver.Error.InvalidContentLength
  alias Quiver.Error.MalformedHeaders
  alias Quiver.Error.ProtocolViolation

  @type parse_state ::
          :idle
          | :status
          | {:headers, non_neg_integer(), [{String.t(), String.t()}]}
          | {:body_content_length, non_neg_integer()}
          | {:body_chunked, chunk_state()}
          | :body_until_close

  @type chunk_state ::
          :chunk_size | {:chunk_data, non_neg_integer()} | :chunk_crlf | :chunk_trailers

  @type response_fragment ::
          {:status, non_neg_integer()}
          | {:headers, [{String.t(), String.t()}]}
          | {:data, binary()}
          | :done

  @spec parse(binary(), parse_state()) ::
          {[response_fragment()], parse_state(), binary()}
          | {:error, term()}
  def parse(data, :status) do
    case find_line(data) do
      {:ok, line, rest} ->
        case parse_status_line(line) do
          {:ok, status} ->
            {[{:status, status}], {:headers, status, []}, rest}

          {:error, _} = error ->
            error
        end

      :incomplete ->
        {[], :status, data}
    end
  end

  def parse(data, {:headers, status, acc}) do
    case find_line(data) do
      {:ok, "", rest} ->
        headers = Enum.reverse(acc)

        case select_body_mode(status, headers) do
          {:error, _} = error ->
            error

          :idle ->
            {[{:headers, headers}, :done], :idle, rest}

          state ->
            {[{:headers, headers}], state, rest}
        end

      {:ok, line, rest} ->
        case parse_header(line) do
          {:ok, header} ->
            parse(rest, {:headers, status, [header | acc]})

          {:error, _} = error ->
            error
        end

      :incomplete ->
        {[], {:headers, status, acc}, data}
    end
  end

  def parse(_data, {:body_content_length, 0}) do
    {[:done], :idle, ""}
  end

  def parse(data, {:body_content_length, remaining}) when byte_size(data) >= remaining do
    <<body::binary-size(remaining), rest::binary>> = data
    {[{:data, body}, :done], :idle, rest}
  end

  def parse(data, {:body_content_length, remaining}) do
    consumed = byte_size(data)
    {[{:data, data}], {:body_content_length, remaining - consumed}, ""}
  end

  def parse(data, {:body_chunked, :chunk_size}) do
    case find_line(data) do
      {:ok, size_line, rest} ->
        size_str = size_line |> String.split(";", parts: 2) |> hd() |> String.trim()
        parse_chunk_size(size_str, size_line, rest, data)

      :incomplete ->
        {[], {:body_chunked, :chunk_size}, data}
    end
  end

  def parse(data, {:body_chunked, {:chunk_data, remaining}})
      when byte_size(data) >= remaining do
    <<chunk::binary-size(remaining), rest::binary>> = data

    case rest do
      <<"\r\n", rest::binary>> ->
        {next_fragments, next_state, next_rest} = parse(rest, {:body_chunked, :chunk_size})
        {[{:data, chunk} | next_fragments], next_state, next_rest}

      _ ->
        {next_fragments, next_state, next_rest} = parse(rest, {:body_chunked, :chunk_crlf})
        {[{:data, chunk} | next_fragments], next_state, next_rest}
    end
  end

  def parse(data, {:body_chunked, {:chunk_data, remaining}}) do
    consumed = byte_size(data)
    {[{:data, data}], {:body_chunked, {:chunk_data, remaining - consumed}}, ""}
  end

  def parse(<<"\r\n", rest::binary>>, {:body_chunked, :chunk_crlf}) do
    parse(rest, {:body_chunked, :chunk_size})
  end

  def parse(data, {:body_chunked, :chunk_crlf}) do
    {[], {:body_chunked, :chunk_crlf}, data}
  end

  def parse(data, {:body_chunked, :chunk_trailers}) do
    case find_line(data) do
      {:ok, "", rest} ->
        {[:done], :idle, rest}

      {:ok, _trailer, rest} ->
        parse(rest, {:body_chunked, :chunk_trailers})

      :incomplete ->
        {[], {:body_chunked, :chunk_trailers}, data}
    end
  end

  def parse("", :body_until_close) do
    {[], :body_until_close, ""}
  end

  def parse(data, :body_until_close) do
    {[{:data, data}], :body_until_close, ""}
  end

  # Private helpers

  defp parse_status_line(line) do
    case String.split(line, " ", parts: 3) do
      ["HTTP/" <> _version, code_str | _rest] ->
        case Integer.parse(code_str) do
          {code, ""} when code >= 100 and code < 600 ->
            {:ok, code}

          _ ->
            {:error, ProtocolViolation.exception(message: "invalid status code: #{code_str}")}
        end

      _ ->
        {:error, ProtocolViolation.exception(message: "malformed status line: #{line}")}
    end
  end

  defp parse_chunk_size(size_str, size_line, rest, _original_data) do
    case Integer.parse(size_str, 16) do
      {0, ""} ->
        parse(rest, {:body_chunked, :chunk_trailers})

      {size, ""} ->
        parse(rest, {:body_chunked, {:chunk_data, size}})

      _ ->
        {:error, ProtocolViolation.exception(message: "invalid chunk size: #{size_line}")}
    end
  end

  defp parse_header(line) do
    case String.split(line, ":", parts: 2) do
      [name, value] ->
        {:ok, {String.downcase(String.trim(name)), String.trim(value)}}

      _ ->
        {:error, MalformedHeaders.exception(message: "malformed header: #{line}")}
    end
  end

  defp select_body_mode(status, _headers) when status in [204, 304], do: :idle

  defp select_body_mode(_status, headers) do
    cond do
      has_header?(headers, "transfer-encoding", "chunked") ->
        {:body_chunked, :chunk_size}

      content_length = get_header(headers, "content-length") ->
        case Integer.parse(content_length) do
          {value, ""} when value >= 0 ->
            {:body_content_length, value}

          _ ->
            {:error,
             InvalidContentLength.exception(message: "invalid content-length: #{content_length}")}
        end

      true ->
        :body_until_close
    end
  end

  defp has_header?(headers, name, value) do
    Enum.any?(headers, fn {n, v} ->
      n == name and String.downcase(v) == value
    end)
  end

  defp get_header(headers, name) do
    case List.keyfind(headers, name, 0) do
      {_, value} -> value
      nil -> nil
    end
  end

  defp find_line(data) do
    case :binary.split(data, "\r\n") do
      [^data] -> :incomplete
      [line, rest] -> {:ok, line, rest}
    end
  end
end
