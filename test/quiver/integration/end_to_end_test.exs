defmodule Quiver.Integration.EndToEndTest do
  use Quiver.TestCase.Integration, async: true

  alias Quiver.TestServer

  setup do
    name = :"e2e_#{System.unique_integer([:positive])}"

    handler = fn conn ->
      case conn.request_path do
        "/json" ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, ~s({"status":"ok"}))

        "/echo" ->
          Plug.Conn.send_resp(conn, 200, "echo")

        "/not-found" ->
          Plug.Conn.send_resp(conn, 404, "not found")

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

    %{name: name, port: port}
  end

  test "full GET request flow", %{name: name, port: port} do
    assert {:ok, %Quiver.Response{status: 200, body: body}} =
             Quiver.new(:get, "http://127.0.0.1:#{port}/json")
             |> Quiver.header("accept", "application/json")
             |> Quiver.request(name)

    assert body =~ "ok"
  end

  test "POST with body", %{name: name, port: port} do
    assert {:ok, %Quiver.Response{status: 200}} =
             Quiver.new(:post, "http://127.0.0.1:#{port}/echo")
             |> Quiver.header("content-type", "text/plain")
             |> Quiver.body("test body")
             |> Quiver.request(name)
  end

  test "non-200 status codes", %{name: name, port: port} do
    assert {:ok, %Quiver.Response{status: 404, body: "not found"}} =
             Quiver.new(:get, "http://127.0.0.1:#{port}/not-found")
             |> Quiver.request(name)
  end

  test "streaming request returns StreamResponse", %{name: name, port: port} do
    assert {:ok, %Quiver.StreamResponse{status: 200, body: body}} =
             Quiver.new(:get, "http://127.0.0.1:#{port}/json")
             |> Quiver.stream_request(name)

    result = body |> Enum.to_list() |> IO.iodata_to_binary()
    assert result =~ "ok"
  end

  test "multiple sequential requests reuse connections", %{name: name, port: port} do
    url = "http://127.0.0.1:#{port}/"

    for _ <- 1..5 do
      assert {:ok, %Quiver.Response{status: 200}} =
               Quiver.new(:get, url) |> Quiver.request(name)
    end

    poll_until(fn ->
      {:ok, stats} = Quiver.pool_stats(name, url)
      stats.active == 0
    end)

    {:ok, stats} = Quiver.pool_stats(name, url)
    assert stats.idle >= 1
  end

  test "concurrent requests", %{name: name, port: port} do
    tasks =
      for i <- 1..5 do
        Task.async(fn ->
          Quiver.new(:get, "http://127.0.0.1:#{port}/req-#{i}")
          |> Quiver.request(name)
        end)
      end

    results = Task.await_many(tasks, 10_000)
    assert Enum.all?(results, &match?({:ok, %Quiver.Response{status: 200}}, &1))
  end

  test "pool_stats returns correct state", %{name: name, port: port} do
    url = "http://127.0.0.1:#{port}/"
    assert {:ok, _} = Quiver.new(:get, url) |> Quiver.request(name)

    assert {:ok, stats} = Quiver.pool_stats(name, url)
    assert is_integer(stats.idle)
    assert is_integer(stats.active)
    assert is_integer(stats.queued)
  end

  test "multiple named instances are independent" do
    name_a = :"e2e_a_#{System.unique_integer([:positive])}"
    name_b = :"e2e_b_#{System.unique_integer([:positive])}"

    {:ok, %{port: port_a} = server_a} =
      TestServer.start(fn conn -> Plug.Conn.send_resp(conn, 200, "a") end)

    {:ok, %{port: port_b} = server_b} =
      TestServer.start(fn conn -> Plug.Conn.send_resp(conn, 201, "b") end)

    {:ok, _} = Quiver.Supervisor.start_link(name: name_a, pools: %{default: [size: 2]})
    {:ok, _} = Quiver.Supervisor.start_link(name: name_b, pools: %{default: [size: 3]})

    assert {:ok, %Quiver.Response{status: 200, body: "a"}} =
             Quiver.new(:get, "http://127.0.0.1:#{port_a}/") |> Quiver.request(name_a)

    assert {:ok, %Quiver.Response{status: 201, body: "b"}} =
             Quiver.new(:get, "http://127.0.0.1:#{port_b}/") |> Quiver.request(name_b)

    TestServer.stop(server_a)
    TestServer.stop(server_b)
  end
end
