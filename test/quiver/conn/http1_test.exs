defmodule Quiver.Conn.HTTP1Test do
  use ExUnit.Case, async: true

  alias Quiver.Conn.HTTP1
  alias Quiver.Conn.HTTP1.Request, as: RequestEncoder
  alias Quiver.TestServer

  setup do
    handler = fn conn -> Plug.Conn.send_resp(conn, 200, "ok") end

    {:ok, %{port: port} = server} = TestServer.start(handler)
    on_exit(fn -> TestServer.stop(server) end)
    %{port: port}
  end

  describe "connect/2" do
    test "connects via http scheme", %{port: port} do
      uri = URI.parse("http://127.0.0.1:#{port}")
      assert {:ok, %HTTP1{scheme: :http}} = HTTP1.connect(uri, [])
    end

    test "returns error for refused connection" do
      uri = URI.parse("http://127.0.0.1:1")
      assert {:error, _} = HTTP1.connect(uri, [])
    end

    test "returns error for unsupported scheme" do
      uri = URI.parse("ftp://example.com")
      assert {:error, %Quiver.Error.InvalidScheme{}} = HTTP1.connect(uri, [])
    end
  end

  describe "open?/1" do
    test "returns true for fresh connection", %{port: port} do
      uri = URI.parse("http://127.0.0.1:#{port}")
      {:ok, conn} = HTTP1.connect(uri, [])
      assert HTTP1.open?(conn)
    end
  end

  describe "close/1" do
    test "closes the connection", %{port: port} do
      uri = URI.parse("http://127.0.0.1:#{port}")
      {:ok, conn} = HTTP1.connect(uri, [])
      assert {:ok, %HTTP1{}} = HTTP1.close(conn)
    end

    test "open? returns false after close", %{port: port} do
      uri = URI.parse("http://127.0.0.1:#{port}")
      {:ok, conn} = HTTP1.connect(uri, [])
      {:ok, conn} = HTTP1.close(conn)
      refute HTTP1.open?(conn)
    end
  end

  describe "request/5" do
    test "sends GET and receives response", %{port: port} do
      uri = URI.parse("http://127.0.0.1:#{port}")
      {:ok, conn} = HTTP1.connect(uri, [])

      assert {:ok, conn, %Quiver.Response{status: 200, body: body}} =
               HTTP1.request(conn, :get, "/", [], nil)

      assert body == "ok"
      assert HTTP1.open?(conn)
    end

    test "sends POST with body" do
      handler = fn conn -> Plug.Conn.send_resp(conn, 201, "created!") end

      {:ok, %{port: port} = server} = TestServer.start(handler)

      uri = URI.parse("http://127.0.0.1:#{port}")
      {:ok, conn} = HTTP1.connect(uri, [])

      assert {:ok, _conn, %Quiver.Response{status: 201, body: body}} =
               HTTP1.request(
                 conn,
                 :post,
                 "/items",
                 [{"content-type", "application/json"}],
                 ~s({"a":1})
               )

      assert body == "created!"
      TestServer.stop(server)
    end

    test "adds host header automatically", %{port: port} do
      uri = URI.parse("http://127.0.0.1:#{port}")
      {:ok, conn} = HTTP1.connect(uri, [])

      assert {:ok, _conn, %Quiver.Response{status: 200}} =
               HTTP1.request(conn, :get, "/", [], nil)
    end

    test "handles chunked response" do
      {:ok, %{port: port} = raw_server} =
        TestServer.start_raw(fn _data ->
          [
            "HTTP/1.1 200 OK\r\n",
            "transfer-encoding: chunked\r\n",
            "\r\n",
            "5\r\nhello\r\n",
            "6\r\n world\r\n",
            "0\r\n\r\n"
          ]
        end)

      uri = URI.parse("http://127.0.0.1:#{port}")
      {:ok, conn} = HTTP1.connect(uri, [])

      assert {:ok, _conn, %Quiver.Response{status: 200, body: body}} =
               HTTP1.request(conn, :get, "/", [], nil)

      assert body == "hello world"
      TestServer.stop(raw_server)
    end

    test "handles 204 no content" do
      handler = fn conn -> Plug.Conn.send_resp(conn, 204, "") end

      {:ok, %{port: port} = server} = TestServer.start(handler)

      uri = URI.parse("http://127.0.0.1:#{port}")
      {:ok, conn} = HTTP1.connect(uri, [])

      assert {:ok, _conn, %Quiver.Response{status: 204, body: nil}} =
               HTTP1.request(conn, :get, "/", [], nil)

      TestServer.stop(server)
    end
  end

  describe "stream/2" do
    test "parses tcp message into response fragments" do
      {:ok, %{port: port} = raw_server} =
        TestServer.start_raw(fn _data ->
          "HTTP/1.1 200 OK\r\ncontent-length: 5\r\n\r\nhello"
        end)

      uri = URI.parse("http://127.0.0.1:#{port}")
      {:ok, conn} = HTTP1.connect(uri, [])

      headers = [{"host", "127.0.0.1:#{port}"}]
      encoded = RequestEncoder.encode(:get, "/", headers, nil)
      {:ok, transport} = conn.transport_mod.send(conn.transport, encoded)
      conn = %{conn | transport: transport, request_state: :in_flight, parse_state: :status}

      {:ok, transport} = conn.transport_mod.activate(conn.transport)
      conn = %{conn | transport: transport}

      all_fragments = recv_stream_loop(conn, [])
      assert Enum.any?(all_fragments, &match?({:status, _ref, 200}, &1))
      assert Enum.any?(all_fragments, &match?({:headers, _ref, _}, &1))
      assert Enum.any?(all_fragments, &match?({:done, _ref}, &1))

      TestServer.stop(raw_server)
    end

    test "returns :unknown for unrelated messages" do
      {:ok, %{port: port} = server} =
        TestServer.start(fn conn -> Plug.Conn.send_resp(conn, 200, "") end)

      uri = URI.parse("http://127.0.0.1:#{port}")
      {:ok, conn} = HTTP1.connect(uri, [])

      assert :unknown = HTTP1.stream(conn, {:tcp, :fake_socket, "data"})

      HTTP1.close(conn)
      TestServer.stop(server)
    end
  end

  describe "keep-alive" do
    test "connection: close marks conn as not reusable" do
      handler = fn conn ->
        conn |> Plug.Conn.put_resp_header("connection", "close") |> Plug.Conn.send_resp(200, "ok")
      end

      {:ok, %{port: port} = server} = TestServer.start(handler)

      uri = URI.parse("http://127.0.0.1:#{port}")
      {:ok, conn} = HTTP1.connect(uri, [])

      {:ok, conn, %Quiver.Response{status: 200}} =
        HTTP1.request(conn, :get, "/", [], nil)

      refute HTTP1.open?(conn)
      TestServer.stop(server)
    end

    test "body_until_close marks conn as not reusable" do
      {:ok, %{port: port} = raw_server} =
        TestServer.start_raw(fn _data ->
          "HTTP/1.1 200 OK\r\n\r\nhello"
        end)

      uri = URI.parse("http://127.0.0.1:#{port}")
      {:ok, conn} = HTTP1.connect(uri, [])

      {:ok, conn, %Quiver.Response{status: 200}} =
        HTTP1.request(conn, :get, "/", [], nil)

      refute HTTP1.open?(conn)
      TestServer.stop(raw_server)
    end

    test "default keep-alive allows reuse with second request" do
      handler = fn conn -> Plug.Conn.send_resp(conn, 200, "ok") end

      {:ok, %{port: port} = server} = TestServer.start(handler)

      uri = URI.parse("http://127.0.0.1:#{port}")
      {:ok, conn} = HTTP1.connect(uri, [])

      {:ok, conn, %Quiver.Response{status: 200}} = HTTP1.request(conn, :get, "/", [], nil)
      assert HTTP1.open?(conn)

      {:ok, _conn, %Quiver.Response{status: 200, body: "ok"}} =
        HTTP1.request(conn, :get, "/second", [], nil)

      TestServer.stop(server)
    end
  end

  describe "stream_request/5" do
    test "streams enumerable body and receives response" do
      handler = fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        Plug.Conn.send_resp(conn, 200, body)
      end

      {:ok, %{port: port} = server} = TestServer.start(handler)

      {:ok, conn} = connect(port)
      chunks = ["hello", " ", "world"]

      assert {:ok, _conn, %Quiver.Response{status: 200, body: "hello world"}} =
               HTTP1.stream_request(
                 conn,
                 :post,
                 "/echo",
                 [{"content-type", "text/plain"}],
                 chunks
               )

      TestServer.stop(server)
    end

    test "streams large body across multiple chunks" do
      handler = fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        Plug.Conn.send_resp(conn, 200, Integer.to_string(byte_size(body)))
      end

      {:ok, %{port: port} = server} = TestServer.start(handler)

      {:ok, conn} = connect(port)
      chunk = String.duplicate("x", 1_000)
      chunks = Stream.repeatedly(fn -> chunk end) |> Stream.take(10)

      assert {:ok, _conn, %Quiver.Response{status: 200, body: "10000"}} =
               HTTP1.stream_request(conn, :post, "/upload", [], chunks)

      TestServer.stop(server)
    end

    test "connection remains open after streaming request" do
      handler = fn conn ->
        {:ok, _body, conn} = Plug.Conn.read_body(conn)
        Plug.Conn.send_resp(conn, 200, "done")
      end

      {:ok, %{port: port} = server} = TestServer.start(handler)

      {:ok, conn} = connect(port)

      {:ok, conn, %Quiver.Response{status: 200}} =
        HTTP1.stream_request(conn, :post, "/", [], ["data"])

      assert HTTP1.open?(conn)
      TestServer.stop(server)
    end

    test "returns error when request already in flight" do
      handler = fn conn -> Plug.Conn.send_resp(conn, 200, "ok") end
      {:ok, %{port: port} = server} = TestServer.start(handler)

      {:ok, conn} = connect(port)
      conn = %{conn | request_state: :in_flight}

      assert {:error, _conn, %Quiver.Error.ProtocolViolation{}} =
               HTTP1.stream_request(conn, :post, "/", [], ["data"])

      TestServer.stop(server)
    end
  end

  describe "recv_response_headers/1 and recv_body_chunk/1" do
    test "receives status and headers eagerly", %{port: port} do
      {:ok, conn} = connect(port)
      {:ok, conn, _ref} = HTTP1.open_request(conn, :get, "/", [], nil)

      assert {:ok, _conn, 200, headers, _initial_chunks} = HTTP1.recv_response_headers(conn)
      assert is_list(headers)
    end

    test "body chunks assemble to full body", %{port: port} do
      {:ok, conn} = connect(port)
      {:ok, conn, _ref} = HTTP1.open_request(conn, :get, "/", [], nil)

      {:ok, conn, _status, _headers, initial_chunks} = HTTP1.recv_response_headers(conn)
      {chunks, _conn} = drain_body(conn, initial_chunks)

      assert IO.iodata_to_binary(chunks) == "ok"
    end

    test "recv_body_chunk returns :done after body is fully consumed", %{port: port} do
      {:ok, conn} = connect(port)
      {:ok, conn, _ref} = HTTP1.open_request(conn, :get, "/", [], nil)

      {:ok, conn, _status, _headers, initial_chunks} = HTTP1.recv_response_headers(conn)
      {_chunks, final_conn} = drain_body(conn, initial_chunks)

      assert {:done, _conn} = HTTP1.recv_body_chunk(final_conn)
    end
  end

  defp connect(port, opts \\ []) do
    HTTP1.connect(URI.parse("http://127.0.0.1:#{port}"), opts)
  end

  defp drain_body(conn, acc) do
    case HTTP1.recv_body_chunk(conn) do
      {:ok, conn, chunk} -> drain_body(conn, acc ++ [chunk])
      {:done, conn} -> {acc, conn}
    end
  end

  defp recv_stream_loop(conn, acc) do
    receive do
      msg ->
        case HTTP1.stream(conn, msg) do
          {:ok, conn, fragments} ->
            all = acc ++ fragments

            if Enum.any?(fragments, &match?({:done, _}, &1)) do
              all
            else
              {:ok, transport} = conn.transport_mod.activate(conn.transport)
              conn = %{conn | transport: transport}
              recv_stream_loop(conn, all)
            end

          {:error, _conn, _reason} ->
            acc

          :unknown ->
            recv_stream_loop(conn, acc)
        end
    after
      5_000 -> acc
    end
  end
end
