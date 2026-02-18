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
end
