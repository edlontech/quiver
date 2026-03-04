defmodule Quiver.Pool.HTTP2Test do
  use Quiver.TestCase.Integration, async: true
  @moduletag :integration

  alias Quiver.Pool.HTTP2, as: Pool
  alias Quiver.TestServer

  defp start_server(handler \\ fn conn -> Plug.Conn.send_resp(conn, 200, "ok") end) do
    TestServer.start(handler, https: true, http_2_only: true)
  end

  describe "start_link/1" do
    test "starts and accepts requests" do
      {:ok, %{port: port, cacerts: cacerts}} = start_server()

      {:ok, pid} =
        Pool.start_link(
          origin: {:https, "127.0.0.1", port},
          pool_opts: [verify: :verify_none, cacerts: cacerts]
        )

      assert {:ok, response} = Pool.request(pid, :get, "/", [], nil, receive_timeout: 5_000)
      assert response.status == 200
    end
  end

  describe "multiplexing" do
    test "handles concurrent requests on single connection" do
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
            Pool.request(pid, :get, "/#{i}", [], nil, receive_timeout: 5_000)
          end)
        end

      results = Task.await_many(tasks, 10_000)
      assert Enum.all?(results, &match?({:ok, %{status: 200}}, &1))

      stats = Pool.stats(pid)
      assert stats.connections == 1
    end
  end

  describe "dynamic scaling" do
    test "POST requests with body" do
      {:ok, %{port: port, cacerts: cacerts}} =
        start_server(fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          Plug.Conn.send_resp(conn, 201, body)
        end)

      {:ok, pid} =
        Pool.start_link(
          origin: {:https, "127.0.0.1", port},
          pool_opts: [
            max_connections: 3,
            verify: :verify_none,
            cacerts: cacerts
          ]
        )

      assert {:ok, resp} =
               Pool.request(pid, :post, "/data", [{"content-type", "text/plain"}], "hello",
                 receive_timeout: 5_000
               )

      assert resp.status == 201
      assert resp.body == "hello"
    end
  end

  describe "stats/1" do
    test "reports zero stats on fresh pool" do
      {:ok, %{port: port, cacerts: cacerts}} = start_server()

      {:ok, pid} =
        Pool.start_link(
          origin: {:https, "127.0.0.1", port},
          pool_opts: [verify: :verify_none, cacerts: cacerts]
        )

      stats = Pool.stats(pid)
      assert stats.active == 0
      assert stats.connections == 0
      assert stats.queued == 0
    end
  end
end
