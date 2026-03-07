defmodule QuiverTest do
  use ExUnit.Case, async: true

  alias Quiver.Request
  alias Quiver.Response
  alias Quiver.Supervisor, as: QuiverSupervisor
  alias Quiver.TestServer

  describe "new/2" do
    test "creates request with method and parsed URI" do
      req = Quiver.new(:get, "https://example.com/api")

      assert %Request{method: :get, url: %URI{}} = req
      assert req.url.scheme == "https"
      assert req.url.host == "example.com"
      assert req.url.path == "/api"
    end

    test "defaults to empty headers and nil body" do
      req = Quiver.new(:post, "http://localhost:8080/path")

      assert req.headers == []
      assert req.body == nil
    end

    test "preserves query string in URI" do
      req = Quiver.new(:get, "https://example.com/search?q=test")

      assert req.url.path == "/search"
      assert req.url.query == "q=test"
    end
  end

  describe "header/3" do
    test "appends a header" do
      req =
        Quiver.new(:get, "https://example.com")
        |> Quiver.header("authorization", "Bearer token")

      assert req.headers == [{"authorization", "Bearer token"}]
    end

    test "preserves insertion order across multiple headers" do
      req =
        Quiver.new(:get, "https://example.com")
        |> Quiver.header("accept", "application/json")
        |> Quiver.header("authorization", "Bearer token")

      assert req.headers == [
               {"accept", "application/json"},
               {"authorization", "Bearer token"}
             ]
    end
  end

  describe "body/2" do
    test "sets binary body" do
      req = Quiver.new(:post, "https://example.com") |> Quiver.body("payload")
      assert req.body == "payload"
    end

    test "sets iodata body" do
      req = Quiver.new(:post, "https://example.com") |> Quiver.body(["a", "b"])
      assert req.body == ["a", "b"]
    end
  end

  describe "stream_body/2" do
    test "sets streaming body from list" do
      req =
        Quiver.new(:post, "https://example.com")
        |> Quiver.stream_body(["chunk1", "chunk2"])

      assert {:stream, enum} = req.body
      assert Enum.to_list(enum) == ["chunk1", "chunk2"]
    end

    test "sets streaming body from Stream" do
      stream = Stream.map(1..3, &Integer.to_string/1)

      req =
        Quiver.new(:put, "https://example.com/upload")
        |> Quiver.stream_body(stream)

      assert {:stream, enum} = req.body
      assert Enum.to_list(enum) == ["1", "2", "3"]
    end

    test "overwrites previously set body" do
      req =
        Quiver.new(:post, "https://example.com")
        |> Quiver.body("old")
        |> Quiver.stream_body(["new"])

      assert {:stream, _} = req.body
    end
  end

  describe "request/2 collected mode" do
    setup do
      name = :"quiver_req_#{System.unique_integer([:positive])}"

      {:ok, %{port: port} = server} =
        TestServer.start(fn conn -> Plug.Conn.send_resp(conn, 200, "hello") end)

      {:ok, _} = QuiverSupervisor.start_link(name: name, pools: %{default: []})

      on_exit(fn -> TestServer.stop(server) end)

      %{name: name, port: port}
    end

    test "executes GET and returns collected response", %{name: name, port: port} do
      assert {:ok, %Response{status: 200, body: "hello"}} =
               Quiver.new(:get, "http://127.0.0.1:#{port}/test")
               |> Quiver.request(name: name)
    end

    test "executes POST with headers and body", %{name: name, port: port} do
      assert {:ok, %Response{status: 200}} =
               Quiver.new(:post, "http://127.0.0.1:#{port}/test")
               |> Quiver.header("content-type", "text/plain")
               |> Quiver.body("payload")
               |> Quiver.request(name: name)
    end

    test "handles URL with query string", %{name: name, port: port} do
      assert {:ok, %Response{status: 200}} =
               Quiver.new(:get, "http://127.0.0.1:#{port}/search?q=test")
               |> Quiver.request(name: name)
    end
  end

  describe "pool_stats/2" do
    setup do
      name = :"stats_#{System.unique_integer([:positive])}"

      {:ok, %{port: port} = server} =
        TestServer.start(fn conn -> Plug.Conn.send_resp(conn, 200, "ok") end)

      {:ok, _} = QuiverSupervisor.start_link(name: name, pools: %{default: []})

      on_exit(fn -> TestServer.stop(server) end)

      %{name: name, port: port}
    end

    test "returns stats after a request creates the pool", %{name: name, port: port} do
      url = "http://127.0.0.1:#{port}/test"
      assert {:ok, _} = Quiver.new(:get, url) |> Quiver.request(name: name)

      assert {:ok, %{idle: _, active: _, queued: _}} = Quiver.pool_stats(url, name: name)
    end

    test "returns error for unknown origin", %{name: name} do
      assert {:error, :not_found} =
               Quiver.pool_stats("http://unknown.test:9999", name: name)
    end
  end

  describe "request/2 upgrade" do
    setup do
      name = :"upgrade_#{System.unique_integer([:positive])}"
      {:ok, port, listen_socket} = start_upgrade_server()
      {:ok, _} = QuiverSupervisor.start_link(name: name, pools: %{default: []})

      on_exit(fn -> :gen_tcp.close(listen_socket) end)

      %{name: name, port: port}
    end

    test "propagates {:upgrade, %Upgrade{}} from pool", %{name: name, port: port} do
      result =
        Quiver.new(:get, "http://127.0.0.1:#{port}/ws")
        |> Quiver.header("upgrade", "websocket")
        |> Quiver.header("connection", "Upgrade")
        |> Quiver.request(name: name)

      assert {:upgrade, %Quiver.Upgrade{status: 101} = upgrade} = result
      assert List.keyfind(upgrade.headers, "upgrade", 0) == {"upgrade", "websocket"}
    end

    test "upgraded transport is usable after top-level request", %{name: name, port: port} do
      {:upgrade, upgrade} =
        Quiver.new(:get, "http://127.0.0.1:#{port}/ws")
        |> Quiver.header("upgrade", "websocket")
        |> Quiver.header("connection", "Upgrade")
        |> Quiver.request(name: name)

      {:ok, transport} = upgrade.transport_mod.send(upgrade.transport, "world")
      {:ok, _transport, data} = upgrade.transport_mod.recv(transport, 0, 2_000)
      assert data == "world"
    end
  end

  describe "stream_request/2" do
    setup do
      name = :"stream_#{System.unique_integer([:positive])}"

      {:ok, %{port: port} = server} =
        TestServer.start(fn conn -> Plug.Conn.send_resp(conn, 200, "hello") end)

      {:ok, _} = QuiverSupervisor.start_link(name: name, pools: %{default: []})

      on_exit(fn -> TestServer.stop(server) end)

      %{name: name, port: port}
    end

    test "returns StreamResponse with lazy body", %{name: name, port: port} do
      assert {:ok, %Quiver.StreamResponse{status: 200, headers: headers, body: body}} =
               Quiver.new(:get, "http://127.0.0.1:#{port}/test")
               |> Quiver.stream_request(name: name)

      assert is_list(headers)
      assert body |> Enum.to_list() |> IO.iodata_to_binary() == "hello"
    end

    test "body stream supports early termination", %{name: name, port: port} do
      assert {:ok, %Quiver.StreamResponse{body: body}} =
               Quiver.new(:get, "http://127.0.0.1:#{port}/test")
               |> Quiver.stream_request(name: name)

      chunks = Enum.take(body, 1)
      assert chunks != []
    end
  end

  defp start_upgrade_server do
    {:ok, listen_socket} =
      :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true, packet: :raw])

    {:ok, port} = :inet.port(listen_socket)
    pid = spawn_link(fn -> upgrade_accept_loop(listen_socket) end)
    :ok = :gen_tcp.controlling_process(listen_socket, pid)

    {:ok, port, listen_socket}
  end

  defp upgrade_accept_loop(listen_socket) do
    case :gen_tcp.accept(listen_socket, 2_000) do
      {:ok, socket} ->
        spawn_link(fn -> handle_upgrade(socket) end)
        upgrade_accept_loop(listen_socket)

      {:error, :timeout} ->
        upgrade_accept_loop(listen_socket)

      {:error, _} ->
        :ok
    end
  end

  defp handle_upgrade(socket) do
    {:ok, _data} = :gen_tcp.recv(socket, 0, 5_000)

    response =
      "HTTP/1.1 101 Switching Protocols\r\n" <>
        "upgrade: websocket\r\n" <>
        "connection: Upgrade\r\n" <>
        "\r\n"

    :gen_tcp.send(socket, response)
    upgrade_echo_loop(socket)
  end

  defp upgrade_echo_loop(socket) do
    case :gen_tcp.recv(socket, 0, 5_000) do
      {:ok, data} ->
        :gen_tcp.send(socket, data)
        upgrade_echo_loop(socket)

      {:error, _} ->
        :gen_tcp.close(socket)
    end
  end
end
