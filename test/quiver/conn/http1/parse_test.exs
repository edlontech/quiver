defmodule Quiver.Conn.HTTP1.ParseTest do
  use ExUnit.Case, async: true

  alias Quiver.Conn.HTTP1.Parse
  alias Quiver.Error.InvalidContentLength
  alias Quiver.Error.MalformedHeaders
  alias Quiver.Error.ProtocolViolation

  describe "parse/2 - status line" do
    test "parses HTTP/1.1 200 OK" do
      {fragments, state, rest} = Parse.parse("HTTP/1.1 200 OK\r\n", :status)

      assert fragments == [{:status, 200}]
      assert match?({:headers, 200, []}, state)
      assert rest == ""
    end

    test "parses HTTP/1.0 404 Not Found" do
      {fragments, state, rest} = Parse.parse("HTTP/1.0 404 Not Found\r\n", :status)

      assert fragments == [{:status, 404}]
      assert match?({:headers, 404, []}, state)
      assert rest == ""
    end

    test "parses status with no reason phrase" do
      {fragments, state, rest} = Parse.parse("HTTP/1.1 204 \r\n", :status)

      assert fragments == [{:status, 204}]
      assert match?({:headers, 204, []}, state)
      assert rest == ""
    end

    test "returns empty fragments on partial status line" do
      {fragments, state, rest} = Parse.parse("HTTP/1.1 200", :status)

      assert fragments == []
      assert state == :status
      assert rest == "HTTP/1.1 200"
    end

    test "returns error on malformed status line" do
      assert {:error, %ProtocolViolation{}} = Parse.parse("GARBAGE\r\n", :status)
    end

    test "returns error on invalid status code" do
      assert {:error, %ProtocolViolation{}} = Parse.parse("HTTP/1.1 abc OK\r\n", :status)
    end

    test "preserves data after status line for next parse" do
      {_fragments, _state, rest} =
        Parse.parse("HTTP/1.1 200 OK\r\ncontent-type: text/plain\r\n", :status)

      assert rest == "content-type: text/plain\r\n"
    end
  end

  describe "parse/2 - headers" do
    test "parses single header and selects body mode" do
      {fragments, _state, rest} =
        Parse.parse("content-length: 5\r\n\r\n", {:headers, 200, []})

      assert [{:headers, [{"content-length", "5"}]}] = fragments
      assert rest == ""
    end

    test "parses multiple headers" do
      data = "content-type: text/plain\r\ncontent-length: 5\r\n\r\n"
      {fragments, _state, _rest} = Parse.parse(data, {:headers, 200, []})

      [{:headers, headers}] = fragments
      assert {"content-type", "text/plain"} in headers
      assert {"content-length", "5"} in headers
    end

    test "handles header with empty value" do
      {fragments, _state, _rest} =
        Parse.parse("x-empty: \r\ncontent-length: 0\r\n\r\n", {:headers, 200, []})

      [{:headers, headers}] = fragments
      assert {"x-empty", ""} in headers
    end

    test "handles duplicate headers" do
      data = "set-cookie: a=1\r\nset-cookie: b=2\r\ncontent-length: 0\r\n\r\n"
      {fragments, _state, _rest} = Parse.parse(data, {:headers, 200, []})

      [{:headers, headers}] = fragments
      cookies = for {"set-cookie", v} <- headers, do: v
      assert "a=1" in cookies
      assert "b=2" in cookies
    end

    test "returns empty fragments on partial headers" do
      {fragments, state, rest} =
        Parse.parse("content-type: text/plain\r\n", {:headers, 200, []})

      assert fragments == []
      assert match?({:headers, 200, [{"content-type", "text/plain"}]}, state)
      assert rest == ""
    end

    test "selects body_content_length when content-length present" do
      data = "content-length: 42\r\n\r\n"
      {_fragments, state, _rest} = Parse.parse(data, {:headers, 200, []})

      assert state == {:body_content_length, 42}
    end

    test "selects body_chunked when transfer-encoding chunked" do
      data = "transfer-encoding: chunked\r\n\r\n"
      {_fragments, state, _rest} = Parse.parse(data, {:headers, 200, []})

      assert state == {:body_chunked, :chunk_size}
    end

    test "selects idle for 204 with no body" do
      data = "x-request-id: abc\r\n\r\n"
      {fragments, state, _rest} = Parse.parse(data, {:headers, 204, []})

      assert [{:headers, _}, :done] = fragments
      assert state == :idle
    end

    test "selects idle for 304 with no body" do
      data = "\r\n"
      {fragments, state, _rest} = Parse.parse(data, {:headers, 304, []})

      assert [{:headers, _}, :done] = fragments
      assert state == :idle
    end

    test "returns error on malformed header line" do
      assert {:error, %MalformedHeaders{}} =
               Parse.parse("no-colon-here\r\n\r\n", {:headers, 200, []})
    end

    test "returns error on non-numeric content-length" do
      assert {:error, %InvalidContentLength{}} =
               Parse.parse("content-length: abc\r\n\r\n", {:headers, 200, []})
    end

    test "returns error on negative content-length" do
      assert {:error, %InvalidContentLength{}} =
               Parse.parse("content-length: -5\r\n\r\n", {:headers, 200, []})
    end
  end

  describe "parse/2 - 1xx informational responses" do
    test "100 Continue is consumed and parser waits for real response" do
      data = "HTTP/1.1 100 Continue\r\n\r\nHTTP/1.1 200 OK\r\ncontent-length: 2\r\n\r\nok"
      {fragments, state, rest} = Parse.parse(data, :status)

      assert fragments == []
      assert state == :status
      assert rest == "HTTP/1.1 200 OK\r\ncontent-length: 2\r\n\r\nok"

      {fragments2, state2, rest2} = Parse.parse(rest, state)
      assert {:status, 200} in fragments2
      refute Enum.any?(fragments2, &match?({:status, 100}, &1))
      assert state2 == {:headers, 200, []}
      assert rest2 == "content-length: 2\r\n\r\nok"
    end

    test "103 Early Hints with headers is consumed before real response" do
      data =
        "HTTP/1.1 103 Early Hints\r\nlink: </style.css>; rel=preload\r\n\r\n" <>
          "HTTP/1.1 200 OK\r\ncontent-length: 5\r\n\r\nhello"

      {fragments, state, rest} = Parse.parse(data, :status)

      assert fragments == []
      assert state == :status
      assert rest == "HTTP/1.1 200 OK\r\ncontent-length: 5\r\n\r\nhello"
    end

    test "multiple 1xx responses before final response" do
      data = "HTTP/1.1 100 Continue\r\n\r\nHTTP/1.1 102 Processing\r\n\r\n"
      {fragments, state, rest} = Parse.parse(data, :status)

      assert fragments == []
      assert state == :status
      assert rest == "HTTP/1.1 102 Processing\r\n\r\n"

      {fragments2, state2, rest2} = Parse.parse(rest, state)
      assert fragments2 == []
      assert state2 == :status
      assert rest2 == ""
    end

    test "101 Switching Protocols is not discarded" do
      data = "HTTP/1.1 101 Switching Protocols\r\nupgrade: websocket\r\n\r\n"
      {fragments, state, rest} = Parse.parse(data, :status)

      assert {:status, 101} in fragments
      assert state == {:headers, 101, []}
      assert rest == "upgrade: websocket\r\n\r\n"

      {fragments2, state2, rest2} = Parse.parse(rest, state)
      assert {:headers, [{"upgrade", "websocket"}]} in fragments2
      assert :done in fragments2
      assert state2 == :idle
      assert rest2 == ""
    end

    test "incomplete 1xx status line waits for more data" do
      {fragments, state, rest} = Parse.parse("HTTP/1.1 100", :status)

      assert fragments == []
      assert state == :status
      assert rest == "HTTP/1.1 100"
    end

    test "incomplete 1xx headers wait for more data" do
      {fragments, state, rest} = Parse.parse("HTTP/1.1 100 Continue\r\n", :status)

      assert fragments == []
      assert state == {:headers, 100, []}
      assert rest == ""

      {fragments2, state2, _rest2} = Parse.parse("some-header: val\r\n", state)
      assert fragments2 == []
      assert {:headers, 100, [{"some-header", "val"}]} = state2
    end
  end

  describe "parse/2 - body content-length" do
    test "parses complete body in one call" do
      {fragments, state, rest} =
        Parse.parse("hello", {:body_content_length, 5})

      assert fragments == [{:data, "hello"}, :done]
      assert state == :idle
      assert rest == ""
    end

    test "parses body across multiple calls" do
      {fragments1, state1, rest1} =
        Parse.parse("hel", {:body_content_length, 5})

      assert fragments1 == [{:data, "hel"}]
      assert state1 == {:body_content_length, 2}
      assert rest1 == ""

      {fragments2, state2, rest2} = Parse.parse("lo", state1)

      assert fragments2 == [{:data, "lo"}, :done]
      assert state2 == :idle
      assert rest2 == ""
    end

    test "handles zero content-length" do
      {fragments, state, rest} =
        Parse.parse("", {:body_content_length, 0})

      assert fragments == [:done]
      assert state == :idle
      assert rest == ""
    end

    test "preserves bytes beyond content-length" do
      {fragments, state, rest} =
        Parse.parse("helloextra", {:body_content_length, 5})

      assert fragments == [{:data, "hello"}, :done]
      assert state == :idle
      assert rest == "extra"
    end
  end

  describe "parse/2 - body chunked" do
    test "parses single chunk" do
      data = "5\r\nhello\r\n0\r\n\r\n"
      {fragments, state, rest} = Parse.parse(data, {:body_chunked, :chunk_size})

      assert [{:data, "hello"}, :done] = fragments
      assert state == :idle
      assert rest == ""
    end

    test "parses multiple chunks" do
      data = "5\r\nhello\r\n6\r\n world\r\n0\r\n\r\n"
      {fragments, state, rest} = Parse.parse(data, {:body_chunked, :chunk_size})

      assert [{:data, "hello"}, {:data, " world"}, :done] = fragments
      assert state == :idle
      assert rest == ""
    end

    test "handles partial chunk data" do
      {fragments, state, rest} = Parse.parse("5\r\nhel", {:body_chunked, :chunk_size})

      assert [{:data, "hel"}] = fragments
      assert state == {:body_chunked, {:chunk_data, 2}}
      assert rest == ""
    end

    test "handles partial chunk size without CRLF" do
      {fragments, state, rest} = Parse.parse("5", {:body_chunked, :chunk_size})

      assert fragments == []
      assert state == {:body_chunked, :chunk_size}
      assert rest == "5"
    end

    test "handles chunk split across calls" do
      {fragments1, state1, _} = Parse.parse("5\r\nhel", {:body_chunked, :chunk_size})
      assert [{:data, "hel"}] = fragments1

      {fragments2, state2, _} = Parse.parse("lo\r\n0\r\n\r\n", state1)
      assert [{:data, "lo"}, :done] = fragments2
      assert state2 == :idle
    end

    test "handles hex chunk sizes" do
      data = "a\r\n0123456789\r\n0\r\n\r\n"
      {fragments, _state, _rest} = Parse.parse(data, {:body_chunked, :chunk_size})

      assert [{:data, "0123456789"}, :done] = fragments
    end

    test "ignores chunk extensions" do
      data = "5;ext=val\r\nhello\r\n0\r\n\r\n"
      {fragments, _state, _rest} = Parse.parse(data, {:body_chunked, :chunk_size})

      assert [{:data, "hello"}, :done] = fragments
    end

    test "emits trailer headers after terminating chunk" do
      data = "0\r\nx-checksum: abc123\r\n\r\n"
      {fragments, state, rest} = Parse.parse(data, {:body_chunked, :chunk_size})

      assert [{:trailers, [{"x-checksum", "abc123"}]}, :done] = fragments
      assert state == :idle
      assert rest == ""
    end

    test "emits multiple trailer headers" do
      data = "0\r\nx-checksum: abc123\r\nx-timing: 42ms\r\n\r\n"
      {fragments, state, rest} = Parse.parse(data, {:body_chunked, :chunk_size})

      assert [{:trailers, trailers}, :done] = fragments
      assert {"x-checksum", "abc123"} in trailers
      assert {"x-timing", "42ms"} in trailers
      assert state == :idle
      assert rest == ""
    end

    test "filters forbidden trailer fields" do
      data =
        "0\r\ntransfer-encoding: chunked\r\ncontent-length: 5\r\nhost: evil\r\nx-checksum: abc\r\n\r\n"

      {fragments, state, rest} = Parse.parse(data, {:body_chunked, :chunk_size})

      assert [{:trailers, [{"x-checksum", "abc"}]}, :done] = fragments
      assert state == :idle
      assert rest == ""
    end

    test "no trailers emits only done" do
      data = "0\r\n\r\n"
      {fragments, state, rest} = Parse.parse(data, {:body_chunked, :chunk_size})

      assert [:done] = fragments
      assert state == :idle
      assert rest == ""
    end

    test "handles CRLF after chunk data arriving in next packet" do
      {fragments1, state1, _} = Parse.parse("5\r\nhello", {:body_chunked, :chunk_size})
      assert [{:data, "hello"}] = fragments1

      {fragments2, state2, rest2} = Parse.parse("\r\n0\r\n\r\n", state1)
      assert [:done] = fragments2
      assert state2 == :idle
      assert rest2 == ""
    end

    test "handles partial CRLF after chunk data (only CR)" do
      {fragments1, state1, _} = Parse.parse("5\r\nhello", {:body_chunked, :chunk_size})
      assert [{:data, "hello"}] = fragments1

      {fragments2, state2, rest2} = Parse.parse("\r", state1)
      assert fragments2 == []
      assert rest2 == "\r"

      {fragments3, state3, rest3} = Parse.parse("\r\n0\r\n\r\n", state2)
      assert [:done] = fragments3
      assert state3 == :idle
      assert rest3 == ""
    end

    test "handles incomplete trailer across calls" do
      {fragments1, state1, rest1} =
        Parse.parse("0\r\nx-checksum: abc", {:body_chunked, :chunk_size})

      assert fragments1 == []
      assert {:body_chunked, {:chunk_trailers, []}} = state1
      assert rest1 == "x-checksum: abc"

      {fragments2, state2, rest2} =
        Parse.parse(rest1 <> "123\r\n\r\n", state1)

      assert [{:trailers, [{"x-checksum", "abc123"}]}, :done] = fragments2
      assert state2 == :idle
      assert rest2 == ""
    end
  end

  describe "parse/2 - body until close" do
    test "emits data fragments" do
      {fragments, state, rest} = Parse.parse("some data", :body_until_close)

      assert fragments == [{:data, "some data"}]
      assert state == :body_until_close
      assert rest == ""
    end

    test "empty data returns no fragments" do
      {fragments, state, rest} = Parse.parse("", :body_until_close)

      assert fragments == []
      assert state == :body_until_close
      assert rest == ""
    end
  end
end
