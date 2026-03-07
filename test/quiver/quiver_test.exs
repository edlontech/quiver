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
end
