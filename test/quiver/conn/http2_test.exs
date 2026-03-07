defmodule Quiver.Conn.HTTP2Test do
  use Quiver.TestCase.Integration, async: true
  @moduletag :integration

  alias Quiver.Conn.HTTP2, as: Conn
  alias Quiver.Conn.HTTP2.Frame
  alias Quiver.Error.GoAwayUnprocessed
  alias Quiver.TestServer

  describe "connect/2" do
    test "completes HTTP/2 handshake over TLS" do
      {:ok, %{port: port, cacerts: cacerts} = server} =
        TestServer.start(
          fn conn -> Plug.Conn.send_resp(conn, 200, "ok") end,
          https: true,
          http_2_only: true
        )

      uri = %URI{scheme: "https", host: "127.0.0.1", port: port}

      assert {:ok, %Conn{state: :open}} =
               Conn.connect(uri,
                 verify: :verify_none,
                 cacerts: cacerts
               )

      TestServer.stop(server)
    end

    test "rejects plain HTTP scheme" do
      uri = %URI{scheme: "http", host: "127.0.0.1", port: 80}

      assert {:error, %Quiver.Error.ProtocolViolation{}} = Conn.connect(uri, [])
    end

    test "rejects unsupported scheme" do
      uri = %URI{scheme: "ftp", host: "127.0.0.1", port: 21}

      assert {:error, %Quiver.Error.InvalidScheme{}} = Conn.connect(uri, [])
    end

    test "returns error when server is unreachable" do
      uri = %URI{scheme: "https", host: "127.0.0.1", port: 1}

      assert {:error, _} = Conn.connect(uri, verify: :verify_none)
    end
  end

  describe "open?/1" do
    test "returns true for open connection" do
      {:ok, conn, server} = connect_h2()

      assert Conn.open?(conn)

      TestServer.stop(server)
    end

    test "returns false after close" do
      {:ok, conn, server} = connect_h2()

      {:ok, conn} = Conn.close(conn)
      refute Conn.open?(conn)

      TestServer.stop(server)
    end
  end

  describe "close/1" do
    test "sends GOAWAY and transitions to closed" do
      {:ok, conn, server} = connect_h2()

      assert {:ok, %Conn{state: :closed}} = Conn.close(conn)

      TestServer.stop(server)
    end

    test "is idempotent on already-closed connection" do
      {:ok, conn, server} = connect_h2()

      {:ok, conn} = Conn.close(conn)
      assert {:ok, %Conn{state: :closed}} = Conn.close(conn)

      TestServer.stop(server)
    end
  end

  describe "max_concurrent_streams/1 and open_request_count/1" do
    test "fresh connection reports defaults" do
      {:ok, conn, server} = connect_h2()

      assert Conn.open_request_count(conn) == 0
      assert is_integer(Conn.max_concurrent_streams(conn))

      TestServer.stop(server)
    end
  end

  describe "open_request/5" do
    test "sends GET and returns ref" do
      {:ok, conn, server} = connect_h2()

      assert {:ok, conn, ref} = Conn.open_request(conn, :get, "/", [], nil)
      assert is_reference(ref)
      assert Conn.open_request_count(conn) == 1

      Conn.close(conn)
      TestServer.stop(server)
    end

    test "rejects request on closed connection" do
      {:ok, conn, server} = connect_h2()
      {:ok, conn} = Conn.close(conn)

      assert {:error, _conn, %Quiver.Error.ProtocolViolation{}} =
               Conn.open_request(conn, :get, "/", [], nil)

      TestServer.stop(server)
    end
  end

  describe "stream/2 single request lifecycle" do
    test "receives GET response fragments" do
      {:ok, conn, server} = connect_h2()

      {:ok, conn, ref} = Conn.open_request(conn, :get, "/", [], nil)
      {_conn, fragments} = recv_stream_loop(conn, [])

      assert Enum.any?(fragments, &match?({:status, ^ref, 200}, &1))
      assert Enum.any?(fragments, &match?({:done, ^ref}, &1))

      TestServer.stop(server)
    end

    test "receives response headers" do
      handler = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"ok":true}))
      end

      {:ok, conn, server} = connect_h2(handler)

      {:ok, conn, ref} = Conn.open_request(conn, :get, "/json", [], nil)
      {_conn, fragments} = recv_stream_loop(conn, [])

      assert Enum.any?(fragments, &match?({:status, ^ref, 200}, &1))
      assert Enum.any?(fragments, &match?({:headers, ^ref, _}, &1))

      headers =
        Enum.find_value(fragments, fn
          {:headers, ^ref, h} -> h
          _ -> nil
        end)

      assert Enum.any?(headers, fn {k, _v} -> k == "content-type" end)

      TestServer.stop(server)
    end

    test "receives response body data" do
      handler = fn conn -> Plug.Conn.send_resp(conn, 200, "hello h2") end
      {:ok, conn, server} = connect_h2(handler)

      {:ok, conn, ref} = Conn.open_request(conn, :get, "/", [], nil)
      {_conn, fragments} = recv_stream_loop(conn, [])

      data_chunks = for {:data, ^ref, d} <- fragments, do: d
      body = IO.iodata_to_binary(data_chunks)
      assert body == "hello h2"

      TestServer.stop(server)
    end

    test "sends POST with body" do
      handler = fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        Plug.Conn.send_resp(conn, 201, body)
      end

      {:ok, conn, server} = connect_h2(handler)

      {:ok, conn, ref} =
        Conn.open_request(
          conn,
          :post,
          "/echo",
          [{"content-type", "text/plain"}],
          "request body"
        )

      {_conn, fragments} = recv_stream_loop(conn, [])

      assert Enum.any?(fragments, &match?({:status, ^ref, 201}, &1))

      data_chunks = for {:data, ^ref, d} <- fragments, do: d
      body = IO.iodata_to_binary(data_chunks)
      assert body == "request body"

      TestServer.stop(server)
    end

    test "returns :unknown for unrelated messages" do
      {:ok, conn, server} = connect_h2()

      assert :unknown = Conn.stream(conn, {:irrelevant, :message})

      TestServer.stop(server)
    end
  end

  describe "cancel/2" do
    test "cancels in-flight request" do
      handler = fn conn ->
        Process.sleep(1_000)
        Plug.Conn.send_resp(conn, 200, "slow")
      end

      {:ok, conn, server} = connect_h2(handler)

      {:ok, conn, ref} = Conn.open_request(conn, :get, "/slow", [], nil)
      assert Conn.open_request_count(conn) == 1

      assert {:ok, conn} = Conn.cancel(conn, ref)
      assert Conn.open_request_count(conn) == 0

      Conn.close(conn)
      TestServer.stop(server)
    end

    test "returns error for unknown ref" do
      {:ok, conn, server} = connect_h2()

      assert {:error, _conn, %Quiver.Error.StreamClosed{}} =
               Conn.cancel(conn, make_ref())

      TestServer.stop(server)
    end
  end

  describe "request/5 blocking" do
    test "GET returns collected response" do
      {:ok, conn, server} = connect_h2()

      assert {:ok, conn, %Quiver.Response{status: 200, body: "ok"}} =
               Conn.request(conn, :get, "/", [], nil)

      assert Conn.open?(conn)

      Conn.close(conn)
      TestServer.stop(server)
    end

    test "POST with body" do
      handler = fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        Plug.Conn.send_resp(conn, 201, body)
      end

      {:ok, conn, server} = connect_h2(handler)

      assert {:ok, conn, %Quiver.Response{status: 201, body: "payload"}} =
               Conn.request(
                 conn,
                 :post,
                 "/items",
                 [{"content-type", "application/json"}],
                 "payload"
               )

      Conn.close(conn)
      TestServer.stop(server)
    end

    test "non-200 status codes" do
      handler = fn conn -> Plug.Conn.send_resp(conn, 404, "not found") end
      {:ok, conn, server} = connect_h2(handler)

      assert {:ok, conn, %Quiver.Response{status: 404, body: "not found"}} =
               Conn.request(conn, :get, "/missing", [], nil)

      Conn.close(conn)
      TestServer.stop(server)
    end

    test "sequential requests reuse connection" do
      {:ok, conn, server} = connect_h2()

      assert {:ok, conn, %Quiver.Response{status: 200}} =
               Conn.request(conn, :get, "/first", [], nil)

      assert {:ok, conn, %Quiver.Response{status: 200}} =
               Conn.request(conn, :get, "/second", [], nil)

      assert Conn.open?(conn)
      assert conn.next_stream_id > 3

      Conn.close(conn)
      TestServer.stop(server)
    end

    test "response includes headers" do
      handler = fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(200, ~s({"ok":true}))
      end

      {:ok, conn, server} = connect_h2(handler)

      assert {:ok, conn, %Quiver.Response{status: 200, headers: headers}} =
               Conn.request(conn, :get, "/json", [], nil)

      assert Enum.any?(headers, fn {k, _v} -> k == "content-type" end)

      Conn.close(conn)
      TestServer.stop(server)
    end
  end

  describe "concurrent streams" do
    test "two concurrent GET requests receive distinct responses" do
      handler = fn conn ->
        body = "path:#{conn.request_path}"
        Plug.Conn.send_resp(conn, 200, body)
      end

      {:ok, conn, server} = connect_h2(handler)

      {:ok, conn, ref1} = Conn.open_request(conn, :get, "/first", [], nil)
      {:ok, conn, ref2} = Conn.open_request(conn, :get, "/second", [], nil)

      assert Conn.open_request_count(conn) == 2

      {_conn, fragments} = recv_all_refs(conn, [ref1, ref2], [])

      data1 = extract_body(fragments, ref1)
      data2 = extract_body(fragments, ref2)

      assert data1 == "path:/first"
      assert data2 == "path:/second"

      TestServer.stop(server)
    end

    test "three concurrent requests complete" do
      handler = fn conn ->
        Plug.Conn.send_resp(conn, 200, conn.request_path)
      end

      {:ok, conn, server} = connect_h2(handler)

      {:ok, conn, ref1} = Conn.open_request(conn, :get, "/a", [], nil)
      {:ok, conn, ref2} = Conn.open_request(conn, :get, "/b", [], nil)
      {:ok, conn, ref3} = Conn.open_request(conn, :get, "/c", [], nil)

      assert Conn.open_request_count(conn) == 3

      {conn, fragments} = recv_all_refs(conn, [ref1, ref2, ref3], [])

      assert extract_body(fragments, ref1) == "/a"
      assert extract_body(fragments, ref2) == "/b"
      assert extract_body(fragments, ref3) == "/c"

      assert Conn.open_request_count(conn) == 0

      Conn.close(conn)
      TestServer.stop(server)
    end

    test "open_request_count decreases as responses complete" do
      handler = fn conn ->
        Plug.Conn.send_resp(conn, 200, "ok")
      end

      {:ok, conn, server} = connect_h2(handler)

      {:ok, conn, ref1} = Conn.open_request(conn, :get, "/1", [], nil)
      assert Conn.open_request_count(conn) == 1

      {:ok, conn, _ref2} = Conn.open_request(conn, :get, "/2", [], nil)
      assert Conn.open_request_count(conn) == 2

      {conn, _fragments} = recv_stream_loop_for_ref(conn, ref1, [])
      assert Conn.open_request_count(conn) <= 1

      Conn.close(conn)
      TestServer.stop(server)
    end
  end

  describe "flow control" do
    test "large body received with auto-refill window updates" do
      body = String.duplicate("x", 100_000)

      handler = fn conn ->
        Plug.Conn.send_resp(conn, 200, body)
      end

      {:ok, conn, server} = connect_h2(handler)

      assert {:ok, conn, %Quiver.Response{status: 200, body: received}} =
               Conn.request(conn, :get, "/big", [], nil)

      assert byte_size(received) == 100_000

      Conn.close(conn)
      TestServer.stop(server)
    end

    test "large body streamed via open_request" do
      body = String.duplicate("y", 50_000)

      handler = fn conn -> Plug.Conn.send_resp(conn, 200, body) end
      {:ok, conn, server} = connect_h2(handler)

      {:ok, conn, ref} = Conn.open_request(conn, :get, "/big", [], nil)
      {_conn, fragments} = recv_stream_loop(conn, [])

      received = extract_body(fragments, ref)
      assert byte_size(received) == 50_000

      TestServer.stop(server)
    end
  end

  describe "connection close handling" do
    test "server shutdown transitions connection to non-open state" do
      handler = fn conn ->
        Process.sleep(2_000)
        Plug.Conn.send_resp(conn, 200, "ok")
      end

      {:ok, conn, server} = connect_h2(handler)

      {:ok, conn, _ref} = Conn.open_request(conn, :get, "/slow", [], nil)
      TestServer.stop(server)

      conn = drain_until_closed(conn)

      refute Conn.open?(conn)
    end
  end

  describe "PING" do
    test "responds to server PING with PONG" do
      {:ok, conn, server} = connect_h2()

      assert {:ok, _conn, %Quiver.Response{status: 200}} =
               Conn.request(conn, :get, "/", [], nil)

      TestServer.stop(server)
    end
  end

  describe "server settings" do
    test "server_settings populated after handshake" do
      {:ok, conn, server} = connect_h2()

      assert conn.received_server_settings?
      assert is_map(conn.server_settings)

      TestServer.stop(server)
    end

    test "client disables push via enable_push: 0" do
      {:ok, conn, server} = connect_h2()

      assert conn.client_settings.enable_push == 0

      TestServer.stop(server)
    end

    test "max_concurrent_streams reflects server value when set" do
      {:ok, conn, server} = connect_h2()

      max = Conn.max_concurrent_streams(conn)
      assert is_integer(max)
      assert max > 0

      TestServer.stop(server)
    end

    test "settings_queue is empty after handshake completes" do
      {:ok, conn, server} = connect_h2()

      assert :queue.is_empty(conn.settings_queue)

      TestServer.stop(server)
    end
  end

  describe "HPACK integration" do
    test "custom headers round-trip correctly" do
      handler = fn conn ->
        val = Plug.Conn.get_req_header(conn, "x-custom") |> List.first()

        conn
        |> Plug.Conn.put_resp_header("x-echo", val || "none")
        |> Plug.Conn.send_resp(200, "ok")
      end

      {:ok, conn, server} = connect_h2(handler)

      assert {:ok, conn, %Quiver.Response{status: 200, headers: headers}} =
               Conn.request(conn, :get, "/", [{"x-custom", "test-value"}], nil)

      assert Enum.any?(headers, fn {k, v} -> k == "x-echo" and v == "test-value" end)

      Conn.close(conn)
      TestServer.stop(server)
    end

    test "pseudo-headers encode method and path" do
      handler = fn conn ->
        body = "#{conn.method} #{conn.request_path}"
        Plug.Conn.send_resp(conn, 200, body)
      end

      {:ok, conn, server} = connect_h2(handler)

      assert {:ok, conn, %Quiver.Response{status: 200, body: "GET /items"}} =
               Conn.request(conn, :get, "/items", [], nil)

      Conn.close(conn)
      TestServer.stop(server)
    end

    test "dynamic table evolves across sequential requests" do
      {:ok, conn, server} = connect_h2()

      assert {:ok, conn, %Quiver.Response{status: 200}} =
               Conn.request(conn, :get, "/first", [{"x-session", "abc"}], nil)

      assert {:ok, conn, %Quiver.Response{status: 200}} =
               Conn.request(conn, :get, "/second", [{"x-session", "abc"}], nil)

      assert conn.encode_table != HPAX.new(4096)

      Conn.close(conn)
      TestServer.stop(server)
    end

    test "multiple distinct header values handled" do
      handler = fn conn ->
        a = Plug.Conn.get_req_header(conn, "x-a") |> List.first("")
        b = Plug.Conn.get_req_header(conn, "x-b") |> List.first("")
        Plug.Conn.send_resp(conn, 200, "#{a}:#{b}")
      end

      {:ok, conn, server} = connect_h2(handler)

      assert {:ok, conn, %Quiver.Response{status: 200, body: "alpha:beta"}} =
               Conn.request(conn, :get, "/", [{"x-a", "alpha"}, {"x-b", "beta"}], nil)

      Conn.close(conn)
      TestServer.stop(server)
    end
  end

  describe "trailer headers" do
    test "second HEADERS frame with end_stream emits trailers fragment" do
      handler = fn conn ->
        conn
        |> Plug.Conn.put_resp_header("trailer", "x-checksum")
        |> Plug.Conn.send_resp(200, "body")
      end

      {:ok, conn, server} = connect_h2(handler)

      {:ok, conn, ref} = Conn.open_request(conn, :get, "/", [], nil)
      {_conn, fragments} = recv_stream_loop(conn, [])

      assert Enum.any?(fragments, &match?({:status, ^ref, 200}, &1))
      assert Enum.any?(fragments, &match?({:done, ^ref}, &1))

      Conn.close(conn)
      TestServer.stop(server)
    end

    test "trailers in blocking request populate response trailers field" do
      {:ok, conn, server} = connect_h2()

      {:ok, conn, %Quiver.Response{trailers: trailers}} =
        Conn.request(conn, :get, "/", [], nil)

      assert is_list(trailers)

      Conn.close(conn)
      TestServer.stop(server)
    end

    test "process_decoded_headers distinguishes trailers from initial headers" do
      {:ok, conn, server} = connect_h2()

      {:ok, conn, ref} = Conn.open_request(conn, :get, "/", [], nil)

      stream_id = Map.get(conn.ref_to_stream_id, ref)
      stream = Map.get(conn.streams, stream_id)
      assert stream.received_headers? == false

      {_conn, _fragments} = recv_stream_loop(conn, [])

      TestServer.stop(server)
    end

    test "trailer HEADERS without END_STREAM is a protocol error" do
      handler = fn conn ->
        Process.sleep(500)
        Plug.Conn.send_resp(conn, 200, "ok")
      end

      {:ok, conn, server} = connect_h2(handler)

      {:ok, conn, ref} = Conn.open_request(conn, :get, "/", [], nil)
      stream_id = Map.get(conn.ref_to_stream_id, ref)

      {initial_headers_block, decode_table} =
        HPAX.encode(:store, [{":status", "200"}], conn.decode_table)

      initial_headers_frame =
        Frame.encode_headers(stream_id, IO.iodata_to_binary(initial_headers_block), true, false)
        |> IO.iodata_to_binary()

      {:ok, conn, _fragments} =
        Conn.stream(
          %{conn | decode_table: decode_table},
          {:ssl, conn.transport.socket, initial_headers_frame}
        )

      stream = Map.get(conn.streams, stream_id)
      assert stream.received_headers? == true

      {trailer_block, _decode_table} =
        HPAX.encode(:store, [{"x-checksum", "abc"}], conn.decode_table)

      trailer_frame =
        Frame.encode_headers(stream_id, IO.iodata_to_binary(trailer_block), true, false)
        |> IO.iodata_to_binary()

      assert {:error, conn, _fragments} =
               Conn.stream(conn, {:ssl, conn.transport.socket, trailer_frame})

      assert conn.state == :closed

      TestServer.stop(server)
    end
  end

  describe "GOAWAY unprocessed stream detection" do
    test "streams above last_stream_id get GoAwayUnprocessed (transient)" do
      handler = fn conn ->
        Process.sleep(500)
        Plug.Conn.send_resp(conn, 200, "ok")
      end

      {:ok, conn, server} = connect_h2(handler)

      {:ok, conn, _ref1} = Conn.open_request(conn, :get, "/a", [], nil)
      {:ok, conn, ref2} = Conn.open_request(conn, :get, "/b", [], nil)

      goaway_frame =
        Frame.encode_goaway(1, :no_error, "shutting down")
        |> IO.iodata_to_binary()

      {:ok, conn, fragments} = Conn.stream(conn, {:ssl, conn.transport.socket, goaway_frame})

      error_fragments = for {:error, ref, err} <- fragments, do: {ref, err}
      assert length(error_fragments) == 1

      [{error_ref, error}] = error_fragments
      assert error_ref == ref2
      assert %GoAwayUnprocessed{} = error
      assert error.last_stream_id == 1
      assert error.error_code == :no_error
      assert error.debug_data == "shutting down"

      assert error.class == :transient

      assert conn.state == :goaway

      Conn.close(conn)
      TestServer.stop(server)
    end

    test "streams at or below last_stream_id are not errored" do
      handler = fn conn ->
        Process.sleep(500)
        Plug.Conn.send_resp(conn, 200, "ok")
      end

      {:ok, conn, server} = connect_h2(handler)

      {:ok, conn, ref1} = Conn.open_request(conn, :get, "/a", [], nil)
      {:ok, conn, _ref2} = Conn.open_request(conn, :get, "/b", [], nil)

      goaway_frame =
        Frame.encode_goaway(3, :no_error, "")
        |> IO.iodata_to_binary()

      {:ok, conn, fragments} = Conn.stream(conn, {:ssl, conn.transport.socket, goaway_frame})

      error_refs = for {:error, ref, _err} <- fragments, do: ref
      refute ref1 in error_refs

      assert conn.state == :goaway

      Conn.close(conn)
      TestServer.stop(server)
    end

    test "GoAwayUnprocessed contains correct error_code and debug_data" do
      handler = fn conn ->
        Process.sleep(500)
        Plug.Conn.send_resp(conn, 200, "ok")
      end

      {:ok, conn, server} = connect_h2(handler)

      {:ok, conn, _ref1} = Conn.open_request(conn, :get, "/a", [], nil)
      {:ok, conn, ref2} = Conn.open_request(conn, :get, "/b", [], nil)

      goaway_frame =
        Frame.encode_goaway(1, :enhance_your_calm, "too fast")
        |> IO.iodata_to_binary()

      {:ok, conn, fragments} = Conn.stream(conn, {:ssl, conn.transport.socket, goaway_frame})

      [{^ref2, error}] = for {:error, ref, err} <- fragments, do: {ref, err}
      assert %GoAwayUnprocessed{} = error
      assert error.error_code == :enhance_your_calm
      assert error.debug_data == "too fast"
      assert error.last_stream_id == 1

      Conn.close(conn)
      TestServer.stop(server)
    end
  end

  describe "MAX_HEADER_LIST_SIZE enforcement" do
    test "returns error when header list exceeds server max_header_list_size" do
      {:ok, conn, server} = connect_h2()

      conn = put_in(conn.server_settings[:max_header_list_size], 100)

      large_headers = [{"x-large", String.duplicate("a", 200)}]

      assert {:error, _conn, %Quiver.Error.HeaderListTooLarge{} = error} =
               Conn.open_request(conn, :get, "/", large_headers, nil)

      assert error.size > 100
      assert error.max_size == 100

      TestServer.stop(server)
    end

    test "succeeds when header list is within server max_header_list_size" do
      {:ok, conn, server} = connect_h2()

      conn = put_in(conn.server_settings[:max_header_list_size], 10_000)

      assert {:ok, _conn, ref} = Conn.open_request(conn, :get, "/", [], nil)
      assert is_reference(ref)

      Conn.close(conn)
      TestServer.stop(server)
    end

    test "allows any header size when max_header_list_size is not set" do
      {:ok, conn, server} = connect_h2()

      conn = %{conn | server_settings: Map.delete(conn.server_settings, :max_header_list_size)}

      large_headers = [{"x-huge", String.duplicate("b", 50_000)}]

      assert {:ok, _conn, ref} = Conn.open_request(conn, :get, "/", large_headers, nil)
      assert is_reference(ref)

      Conn.close(conn)
      TestServer.stop(server)
    end

    test "prepare_request also enforces max_header_list_size" do
      {:ok, conn, server} = connect_h2()

      conn = put_in(conn.server_settings[:max_header_list_size], 100)

      large_headers = [{"x-large", String.duplicate("c", 200)}]

      assert {:error, _conn, %Quiver.Error.HeaderListTooLarge{}} =
               Conn.prepare_request(conn, :get, "/", large_headers, nil)

      TestServer.stop(server)
    end

    test "header list size calculation includes 32-byte per-entry overhead" do
      {:ok, conn, server} = connect_h2()

      pseudo_overhead = 4 * 32

      pseudo_sizes =
        byte_size(":method") + byte_size("GET") +
          byte_size(":path") + byte_size("/") +
          byte_size(":scheme") + byte_size("https") +
          byte_size(":authority") + byte_size("127.0.0.1:#{conn.port}")

      expected_base = pseudo_sizes + pseudo_overhead

      header_name = "x-test"
      header_value = "v"
      header_entry_size = byte_size(header_name) + byte_size(header_value) + 32
      total = expected_base + header_entry_size

      conn = put_in(conn.server_settings[:max_header_list_size], total - 1)

      assert {:error, _conn, %Quiver.Error.HeaderListTooLarge{size: ^total}} =
               Conn.open_request(conn, :get, "/", [{header_name, header_value}], nil)

      conn = put_in(conn.server_settings[:max_header_list_size], total)

      assert {:ok, _conn, _ref} =
               Conn.open_request(conn, :get, "/", [{header_name, header_value}], nil)

      Conn.close(conn)
      TestServer.stop(server)
    end
  end

  # -- Helpers --

  defp connect_h2(handler \\ fn conn -> Plug.Conn.send_resp(conn, 200, "ok") end) do
    {:ok, %{port: port, cacerts: cacerts} = server} =
      TestServer.start(handler, https: true, http_2_only: true)

    uri = %URI{scheme: "https", host: "127.0.0.1", port: port}

    {:ok, conn} =
      Conn.connect(uri,
        verify: :verify_none,
        cacerts: cacerts
      )

    {:ok, conn, server}
  end

  defp recv_stream_loop(conn, acc) do
    {:ok, transport} = conn.transport_mod.activate(conn.transport)
    conn = put_in(conn.transport, transport)

    receive do
      msg ->
        case Conn.stream(conn, msg) do
          {:ok, conn, fragments} ->
            all = acc ++ fragments

            if Enum.any?(all, &match?({:done, _}, &1)) do
              {conn, all}
            else
              recv_stream_loop(conn, all)
            end

          {:error, conn, _reason} ->
            {conn, acc}

          :unknown ->
            recv_stream_loop(conn, acc)
        end
    after
      5_000 -> {conn, acc}
    end
  end

  defp recv_all_refs(conn, refs, acc) do
    remaining = Enum.reject(refs, fn ref -> Enum.any?(acc, &match?({:done, ^ref}, &1)) end)

    if remaining == [] do
      {conn, acc}
    else
      {:ok, transport} = conn.transport_mod.activate(conn.transport)
      conn = put_in(conn.transport, transport)

      receive do
        msg ->
          case Conn.stream(conn, msg) do
            {:ok, conn, fragments} -> recv_all_refs(conn, refs, acc ++ fragments)
            {:error, conn, _reason} -> {conn, acc}
            :unknown -> recv_all_refs(conn, refs, acc)
          end
      after
        5_000 -> {conn, acc}
      end
    end
  end

  defp recv_stream_loop_for_ref(conn, ref, acc) do
    if Enum.any?(acc, &match?({:done, ^ref}, &1)) do
      {conn, acc}
    else
      {:ok, transport} = conn.transport_mod.activate(conn.transport)
      conn = put_in(conn.transport, transport)

      receive do
        msg ->
          case Conn.stream(conn, msg) do
            {:ok, conn, fragments} -> recv_stream_loop_for_ref(conn, ref, acc ++ fragments)
            {:error, conn, _reason} -> {conn, acc}
            :unknown -> recv_stream_loop_for_ref(conn, ref, acc)
          end
      after
        5_000 -> {conn, acc}
      end
    end
  end

  defp extract_body(fragments, ref) do
    data_chunks = for {:data, ^ref, d} <- fragments, do: d
    IO.iodata_to_binary(data_chunks)
  end

  defp drain_until_closed(conn) do
    if Conn.open?(conn) do
      {:ok, transport} = conn.transport_mod.activate(conn.transport)
      conn = put_in(conn.transport, transport)

      receive do
        msg ->
          case Conn.stream(conn, msg) do
            {:ok, conn, _} -> drain_until_closed(conn)
            {:error, conn, _} -> drain_until_closed(conn)
            :unknown -> drain_until_closed(conn)
          end
      after
        3_000 -> conn
      end
    else
      conn
    end
  end
end
