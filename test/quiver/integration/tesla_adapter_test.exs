defmodule Quiver.Integration.TeslaAdapterTest do
  use Quiver.TestCase.Integration, async: true
  @moduletag :integration

  alias Quiver.TestServer

  setup do
    name = :"tesla_adapter_#{System.unique_integer([:positive])}"

    handler = fn conn ->
      case {conn.method, conn.request_path} do
        {"GET", "/hello"} ->
          Plug.Conn.send_resp(conn, 200, "world")

        {"POST", "/echo"} ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          Plug.Conn.send_resp(conn, 200, body)

        {"GET", "/not-found"} ->
          Plug.Conn.send_resp(conn, 404, "gone")

        {"GET", "/headers"} ->
          value =
            conn.req_headers
            |> Enum.find_value(fn {k, v} -> if k == "x-custom", do: v end)

          Plug.Conn.send_resp(conn, 200, value || "")

        {"GET", "/query"} ->
          Plug.Conn.send_resp(conn, 200, conn.query_string)

        {"GET", "/resp-headers"} ->
          conn
          |> Plug.Conn.put_resp_header("x-server", "quiver")
          |> Plug.Conn.send_resp(200, "ok")

        {"GET", "/nil-body"} ->
          Plug.Conn.send_resp(conn, 204, "")

        {"GET", "/stream"} ->
          conn = Plug.Conn.send_chunked(conn, 200)
          {:ok, conn} = Plug.Conn.chunk(conn, "chunk1")
          {:ok, conn} = Plug.Conn.chunk(conn, "chunk2")
          {:ok, conn} = Plug.Conn.chunk(conn, "chunk3")
          conn

        _ ->
          Plug.Conn.send_resp(conn, 200, "ok")
      end
    end

    {:ok, %{port: port} = server} = TestServer.start(handler)

    {:ok, _} =
      Quiver.Supervisor.start_link(
        name: name,
        pools: %{default: [size: 5]}
      )

    on_exit(fn -> TestServer.stop(server) end)

    client = Tesla.client([], {Tesla.Adapter.Quiver, name: name})

    %{name: name, port: port, client: client}
  end

  describe "buffered requests" do
    test "GET returns status and body", %{client: client, port: port} do
      assert {:ok, %Tesla.Env{status: 200, body: "world"}} =
               Tesla.get(client, "http://127.0.0.1:#{port}/hello")
    end

    test "POST sends and receives body", %{client: client, port: port} do
      assert {:ok, %Tesla.Env{status: 200, body: "ping"}} =
               Tesla.post(client, "http://127.0.0.1:#{port}/echo", "ping")
    end

    test "non-200 status codes pass through", %{client: client, port: port} do
      assert {:ok, %Tesla.Env{status: 404, body: "gone"}} =
               Tesla.get(client, "http://127.0.0.1:#{port}/not-found")
    end

    test "request headers are forwarded", %{client: client, port: port} do
      assert {:ok, %Tesla.Env{status: 200, body: "test-value"}} =
               Tesla.get(client, "http://127.0.0.1:#{port}/headers",
                 headers: [{"x-custom", "test-value"}]
               )
    end

    test "query parameters are included in URL", %{client: client, port: port} do
      assert {:ok, %Tesla.Env{status: 200, body: body}} =
               Tesla.get(client, "http://127.0.0.1:#{port}/query", query: [foo: "bar", baz: "1"])

      assert body =~ "foo=bar"
      assert body =~ "baz=1"
    end

    test "response headers are mapped back", %{client: client, port: port} do
      assert {:ok, %Tesla.Env{status: 200, headers: headers}} =
               Tesla.get(client, "http://127.0.0.1:#{port}/resp-headers")

      assert Enum.any?(headers, fn {k, v} -> k == "x-server" and v == "quiver" end)
    end

    test "nil body is handled", %{client: client, port: port} do
      assert {:ok, %Tesla.Env{status: 204}} =
               Tesla.get(client, "http://127.0.0.1:#{port}/nil-body")
    end
  end

  describe "streaming requests" do
    test "returns lazy body stream", %{name: name, port: port} do
      client = Tesla.client([], {Tesla.Adapter.Quiver, name: name, response: :stream})

      assert {:ok, %Tesla.Env{status: 200, body: body}} =
               Tesla.get(client, "http://127.0.0.1:#{port}/stream")

      refute is_binary(body)
      result = body |> Enum.to_list() |> IO.iodata_to_binary()
      assert result =~ "chunk1chunk2chunk3"
    end
  end

  describe "error handling" do
    test "missing :name option returns ArgumentError" do
      client = Tesla.client([], {Tesla.Adapter.Quiver, []})

      assert {:error, %ArgumentError{}} =
               Tesla.get(client, "http://127.0.0.1:9999/whatever")
    end

    test "connection failure passes through Quiver error", %{name: name} do
      client = Tesla.client([], {Tesla.Adapter.Quiver, name: name})

      assert {:error, _reason} =
               Tesla.get(client, "http://127.0.0.1:1/unreachable")
    end
  end
end
