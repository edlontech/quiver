defmodule Quiver.Pool.ManagerTest do
  use ExUnit.Case, async: true
  @moduletag :integration

  alias Quiver.Pool.HTTP2
  alias Quiver.Pool.Manager
  alias Quiver.TestServer

  setup do
    name = :"test_mgr_#{System.unique_integer([:positive])}"

    {:ok, %{port: port} = server} =
      TestServer.start(fn conn -> Plug.Conn.send_resp(conn, 200, "ok") end)

    {:ok, _sup} =
      Quiver.Supervisor.start_link(
        name: name,
        pools: %{
          "http://127.0.0.1:#{port}" => [size: 2],
          "http://*.local:#{port}" => [size: 3],
          :default => [size: 1]
        }
      )

    on_exit(fn -> TestServer.stop(server) end)

    %{name: name, port: port}
  end

  describe "get_pool/2" do
    test "creates pool on first request", %{name: name, port: port} do
      origin = {:http, "127.0.0.1", port}
      assert {:ok, pool} = Manager.get_pool(name, origin)
      assert is_pid(pool)
    end

    test "returns same pool on second call", %{name: name, port: port} do
      origin = {:http, "127.0.0.1", port}
      assert {:ok, pool1} = Manager.get_pool(name, origin)
      assert {:ok, pool2} = Manager.get_pool(name, origin)
      assert pool1 == pool2
    end

    test "creates separate pools per origin", %{name: name, port: port} do
      origin1 = {:http, "127.0.0.1", port}
      origin2 = {:http, "other.local", port}

      assert {:ok, pool1} = Manager.get_pool(name, origin1)
      assert {:ok, pool2} = Manager.get_pool(name, origin2)
      assert pool1 != pool2
    end

    test "handles concurrent first requests to same origin", %{name: name, port: port} do
      origin = {:http, "127.0.0.1", port}

      tasks =
        for _ <- 1..5 do
          Task.async(fn -> Manager.get_pool(name, origin) end)
        end

      results = Task.await_many(tasks, 5_000)
      pids = Enum.map(results, fn {:ok, pid} -> pid end) |> Enum.uniq()

      assert length(pids) == 1
    end
  end

  describe "pool_stats/2" do
    test "returns stats for existing pool", %{name: name, port: port} do
      origin = {:http, "127.0.0.1", port}
      {:ok, _pool} = Manager.get_pool(name, origin)

      assert {:ok, %{idle: _, active: _, queued: _}} = Manager.pool_stats(name, origin)
    end

    test "returns error for unknown origin", %{name: name} do
      assert {:error, :not_found} = Manager.pool_stats(name, {:http, "nonexistent.com", 9999})
    end
  end

  describe "protocol routing" do
    test "starts HTTP/2 pool when protocol: :http2" do
      {:ok, %{port: port, cacerts: cacerts}} =
        TestServer.start(fn conn -> Plug.Conn.send_resp(conn, 200, "h2") end,
          https: true,
          http_2_only: true
        )

      h2_name = :"test_h2_#{System.unique_integer([:positive])}"

      start_supervised!(
        {Quiver.Supervisor,
         name: h2_name,
         pools: %{
           default: [protocol: :http2, verify: :verify_none, cacerts: cacerts]
         }}
      )

      origin = {:https, "127.0.0.1", port}
      {:ok, pool_pid} = Manager.get_pool(h2_name, origin)

      assert {:ok, response} =
               HTTP2.request(pool_pid, :get, "/", [], nil, receive_timeout: 5_000)

      assert response.status == 200
    end
  end
end
