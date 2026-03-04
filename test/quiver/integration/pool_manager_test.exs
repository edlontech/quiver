defmodule Quiver.Integration.PoolManagerTest do
  use ExUnit.Case, async: true
  @moduletag :integration

  alias Quiver.Pool.HTTP1, as: Pool
  alias Quiver.Pool.Manager
  alias Quiver.TestServer

  setup do
    name = :"integ_#{System.unique_integer([:positive])}"

    {:ok, %{port: port} = server} =
      TestServer.start(fn conn -> Plug.Conn.send_resp(conn, 200, "ok") end)

    {:ok, _sup} =
      Quiver.Supervisor.start_link(
        name: name,
        pools: %{
          "http://127.0.0.1:#{port}" => [size: 3],
          "http://*.local:#{port}" => [size: 2],
          :default => [size: 1]
        }
      )

    on_exit(fn -> TestServer.stop(server) end)

    %{name: name, port: port}
  end

  test "full flow: get pool, make request, check stats", %{name: name, port: port} do
    origin = {:http, "127.0.0.1", port}

    {:ok, pool} = Manager.get_pool(name, origin)
    assert {:ok, %Quiver.Response{status: 200}} = Pool.request(pool, :get, "/", [], nil)

    {:ok, stats} = Manager.pool_stats(name, origin)
    assert is_map_key(stats, :idle)
    assert is_map_key(stats, :active)
    assert is_map_key(stats, :queued)
  end

  test "concurrent pool creation for multiple origins", %{name: name, port: port} do
    origins = [
      {:http, "127.0.0.1", port},
      {:http, "foo.local", port},
      {:http, "bar.local", port}
    ]

    tasks =
      for origin <- origins do
        Task.async(fn -> Manager.get_pool(name, origin) end)
      end

    results = Task.await_many(tasks, 5_000)
    assert Enum.all?(results, &match?({:ok, pid} when is_pid(pid), &1))

    pools =
      Enum.map(results, fn {:ok, pid} -> pid end)
      |> Enum.uniq()

    assert length(pools) == 3
  end

  test "pool survives after making requests", %{name: name, port: port} do
    origin = {:http, "127.0.0.1", port}
    {:ok, pool} = Manager.get_pool(name, origin)

    for _ <- 1..5 do
      assert {:ok, %Quiver.Response{status: 200}} = Pool.request(pool, :get, "/", [], nil)
    end

    {:ok, same_pool} = Manager.get_pool(name, origin)
    assert same_pool == pool
    assert Process.alive?(pool)
  end

  test "wildcard config applies to matching origins", %{name: name, port: port} do
    {:ok, pool1} = Manager.get_pool(name, {:http, "foo.local", port})
    {:ok, pool2} = Manager.get_pool(name, {:http, "bar.local", port})

    assert pool1 != pool2
    assert Process.alive?(pool1)
    assert Process.alive?(pool2)
  end

  test "default config applies to unmatched origins", %{name: name, port: port} do
    {:ok, pool} = Manager.get_pool(name, {:http, "unknown.example.com", port})
    assert Process.alive?(pool)
  end
end
