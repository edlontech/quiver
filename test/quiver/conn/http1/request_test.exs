defmodule Quiver.Conn.HTTP1.RequestTest do
  use ExUnit.Case, async: true

  alias Quiver.Conn.HTTP1.Request

  describe "encode/4" do
    test "encodes GET request with no body" do
      result = Request.encode(:get, "/api/users", [{"host", "example.com"}], nil)
      encoded = IO.iodata_to_binary(result)

      assert encoded == "GET /api/users HTTP/1.1\r\nhost: example.com\r\n\r\n"
    end

    test "encodes POST request with body and auto content-length" do
      body = ~s({"name":"test"})

      result =
        Request.encode(
          :post,
          "/api/users",
          [{"host", "example.com"}, {"content-type", "application/json"}],
          body
        )

      encoded = IO.iodata_to_binary(result)

      assert encoded =~ "POST /api/users HTTP/1.1\r\n"
      assert encoded =~ "content-length: #{byte_size(body)}\r\n"
      assert encoded =~ "content-type: application/json\r\n"
      assert String.ends_with?(encoded, "\r\n\r\n" <> body)
    end

    test "does not add content-length when body is nil" do
      result = Request.encode(:get, "/", [{"host", "example.com"}], nil)
      encoded = IO.iodata_to_binary(result)

      refute encoded =~ "content-length"
    end

    test "does not override existing content-length" do
      result =
        Request.encode(
          :post,
          "/",
          [{"host", "example.com"}, {"content-length", "99"}],
          "short"
        )

      encoded = IO.iodata_to_binary(result)

      assert encoded =~ "content-length: 99\r\n"
      refute encoded =~ "content-length: 5\r\n"
    end

    test "encodes iodata body" do
      body = ["hello", " ", "world"]
      result = Request.encode(:post, "/", [{"host", "example.com"}], body)
      encoded = IO.iodata_to_binary(result)

      assert encoded =~ "content-length: 11\r\n"
      assert String.ends_with?(encoded, "\r\n\r\nhello world")
    end

    test "uppercases method in request line" do
      result = Request.encode(:delete, "/resource/1", [{"host", "example.com"}], nil)
      encoded = IO.iodata_to_binary(result)

      assert encoded =~ "DELETE /resource/1 HTTP/1.1\r\n"
    end

    test "returns iodata, not a binary" do
      result = Request.encode(:get, "/", [{"host", "example.com"}], nil)
      assert is_list(result)
    end
  end

  describe "encode/4 with :stream" do
    test "encodes headers with chunked transfer-encoding" do
      encoded = Request.encode(:post, "/upload", [{"host", "example.com"}], :stream)
      result = IO.iodata_to_binary(encoded)

      assert result =~ "POST /upload HTTP/1.1\r\n"
      assert result =~ "transfer-encoding: chunked\r\n"
      assert String.ends_with?(result, "\r\n\r\n")
      refute result =~ "content-length"
    end

    test "does not add chunked if transfer-encoding already present" do
      headers = [{"host", "example.com"}, {"transfer-encoding", "chunked"}]
      encoded = Request.encode(:post, "/upload", headers, :stream)
      result = IO.iodata_to_binary(encoded)

      occurrences = length(String.split(result, "transfer-encoding")) - 1
      assert occurrences == 1
    end

    test "does not include a body" do
      encoded = Request.encode(:post, "/upload", [{"host", "example.com"}], :stream)
      result = IO.iodata_to_binary(encoded)

      assert String.ends_with?(result, "\r\n\r\n")
      [_headers, body] = String.split(result, "\r\n\r\n", parts: 2)
      assert body == ""
    end
  end

  describe "encode_chunk/1" do
    test "wraps data in chunked encoding format" do
      chunk = Request.encode_chunk("Hello")
      assert IO.iodata_to_binary(chunk) == "5\r\nHello\r\n"
    end

    test "handles iodata input" do
      chunk = Request.encode_chunk(["He", "llo"])
      assert IO.iodata_to_binary(chunk) == "5\r\nHello\r\n"
    end

    test "encodes hex size correctly for larger data" do
      data = String.duplicate("x", 255)
      chunk = Request.encode_chunk(data)
      assert IO.iodata_to_binary(chunk) == "FF\r\n#{data}\r\n"
    end
  end

  describe "encode_last_chunk/0" do
    test "returns terminal chunk" do
      assert Request.encode_last_chunk() == "0\r\n\r\n"
    end
  end
end
