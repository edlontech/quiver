defmodule Quiver.Pool.HTTP2IntegrationTest do
  use Quiver.TestCase.Integration, async: true
  @moduletag :integration
  use AssertEventually, timeout: 2_000, interval: 50

  alias Quiver.Pool.HTTP2, as: Pool
  alias Quiver.Pool.Manager
  alias Quiver.Response
  alias Quiver.StreamResponse
  alias Quiver.TestServer

  defp start_server(handler \\ fn conn -> Plug.Conn.send_resp(conn, 200, "ok") end) do
    TestServer.start(handler, https: true, http_2_only: true)
  end

  describe "Quiver.stream_request/2 with HTTP/2" do
    test "streams response from HTTP/2 server" do
      {:ok, %{port: port, cacerts: cacerts}} =
        start_server(fn conn -> Plug.Conn.send_resp(conn, 200, "h2 streaming") end)

      name = :"h2_stream_#{System.unique_integer([:positive])}"

      start_supervised!(
        {Quiver.Supervisor,
         name: name,
         pools: %{
           default: [protocol: :http2, verify: :verify_none, cacerts: cacerts]
         }}
      )

      assert {:ok, %StreamResponse{status: 200, body: body}} =
               Quiver.new(:get, "https://127.0.0.1:#{port}/")
               |> Quiver.stream_request(name: name)

      assert body |> Enum.to_list() |> IO.iodata_to_binary() == "h2 streaming"
    end
  end

  describe "end-to-end through Manager" do
    test "request through supervision tree" do
      {:ok, %{port: port, cacerts: cacerts}} = start_server()

      name = :"e2e_h2_#{System.unique_integer([:positive])}"

      start_supervised!(
        {Quiver.Supervisor,
         name: name,
         pools: %{
           default: [protocol: :http2, verify: :verify_none, cacerts: cacerts]
         }}
      )

      origin = {:https, "127.0.0.1", port}
      {:ok, pool_pid} = Manager.get_pool(name, origin)

      assert {:ok, resp} = Pool.request(pool_pid, :get, "/", [], nil, recv_timeout: 5_000)
      assert resp.status == 200
      assert resp.body == "ok"
    end
  end

  describe "concurrent multiplexing through pool" do
    test "10 concurrent requests multiplex on single connection" do
      {:ok, %{port: port, cacerts: cacerts}} =
        start_server(fn conn ->
          Process.sleep(50)
          Plug.Conn.send_resp(conn, 200, conn.request_path)
        end)

      {:ok, pid} =
        Pool.start_link(
          origin: {:https, "127.0.0.1", port},
          pool_opts: [
            max_connections: 1,
            verify: :verify_none,
            cacerts: cacerts
          ]
        )

      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            Pool.request(pid, :get, "/req/#{i}", [], nil, recv_timeout: 10_000)
          end)
        end

      results = Task.await_many(tasks, 15_000)

      successes = Enum.filter(results, &match?({:ok, _}, &1))
      assert length(successes) == 10

      stats = Pool.stats(pid)
      assert stats.connections == 1
      assert stats.active == 0
    end
  end

  describe "streaming" do
    test "stream_request returns StreamResponse with lazy body" do
      {:ok, %{port: port, cacerts: cacerts}} =
        start_server(fn conn -> Plug.Conn.send_resp(conn, 200, "hello stream") end)

      {:ok, pid} =
        Pool.start_link(
          origin: {:https, "127.0.0.1", port},
          pool_opts: [verify: :verify_none, cacerts: cacerts]
        )

      assert {:ok, %StreamResponse{status: 200, headers: headers, body: body}} =
               Pool.stream_request(pid, :get, "/", [], nil, recv_timeout: 5_000)

      assert is_list(headers)
      assert body |> Enum.to_list() |> IO.iodata_to_binary() == "hello stream"
    end

    test "concurrent streaming and collected requests on same connection" do
      {:ok, %{port: port, cacerts: cacerts}} =
        start_server(fn conn ->
          Process.sleep(20)
          Plug.Conn.send_resp(conn, 200, "hello")
        end)

      {:ok, pid} =
        Pool.start_link(
          origin: {:https, "127.0.0.1", port},
          pool_opts: [
            max_connections: 1,
            verify: :verify_none,
            cacerts: cacerts
          ]
        )

      stream_task =
        Task.async(fn ->
          Pool.stream_request(pid, :get, "/", [], nil, recv_timeout: 5_000)
        end)

      collected_task =
        Task.async(fn ->
          Pool.request(pid, :get, "/", [], nil, recv_timeout: 5_000)
        end)

      {:ok, %StreamResponse{body: body}} = Task.await(stream_task, 10_000)
      {:ok, %Response{status: 200}} = Task.await(collected_task, 10_000)

      assert body |> Enum.to_list() |> IO.iodata_to_binary() == "hello"
    end

    test "early stream halt via Enum.take does not kill connection" do
      {:ok, %{port: port, cacerts: cacerts}} =
        start_server(fn conn ->
          body = String.duplicate("x", 500)
          Plug.Conn.send_resp(conn, 200, body)
        end)

      {:ok, pid} =
        Pool.start_link(
          origin: {:https, "127.0.0.1", port},
          pool_opts: [verify: :verify_none, cacerts: cacerts]
        )

      {:ok, %StreamResponse{body: body}} =
        Pool.stream_request(pid, :get, "/", [], nil, recv_timeout: 5_000)

      chunks = Enum.take(body, 1)
      assert chunks != []

      assert_eventually(Pool.stats(pid).active == 0)

      assert {:ok, %Response{status: 200}} =
               Pool.request(pid, :get, "/", [], nil, recv_timeout: 5_000)
    end
  end

  describe "connection recovery" do
    test "returns to idle state after all connections die" do
      {:ok, %{port: port, cacerts: cacerts, server: server, agent: agent}} = start_server()

      {:ok, pid} =
        Pool.start_link(
          origin: {:https, "127.0.0.1", port},
          pool_opts: [
            max_connections: 2,
            verify: :verify_none,
            cacerts: cacerts
          ]
        )

      assert {:ok, %{status: 200}} =
               Pool.request(pid, :get, "/first", [], nil, recv_timeout: 5_000)

      assert Pool.stats(pid).connections == 1

      TestServer.stop(%{server: server, agent: agent})
      Process.sleep(300)

      assert Pool.stats(pid).connections == 0
    end
  end
end
