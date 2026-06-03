defmodule Quiver.Pool.HTTP2ResilienceTest do
  use Quiver.TestCase.Integration, async: false
  @moduletag :integration

  alias Quiver.Pool.HTTP2, as: Pool
  alias Quiver.TestServer

  defp connection_pids(pool) do
    pool
    |> :sys.get_state()
    |> elem(1)
    |> Map.fetch!(:connections)
    |> Map.keys()
  end

  test "coordinator survives an abnormal worker exit" do
    Process.flag(:trap_exit, true)

    {:ok, %{port: port, cacerts: cacerts}} =
      TestServer.start(fn conn -> Plug.Conn.send_resp(conn, 200, "ok") end,
        https: true,
        http_2_only: true
      )

    {:ok, pool} =
      Pool.start_link(
        origin: {:https, "127.0.0.1", port},
        pool_opts: [verify: :verify_none, cacerts: cacerts]
      )

    assert {:ok, %{status: 200}} = Pool.request(pool, :get, "/", [], nil, receive_timeout: 5_000)

    [worker] = connection_pids(pool)
    pool_mon = Process.monitor(pool)

    Process.exit(worker, :kill)

    refute_receive {:DOWN, ^pool_mon, :process, ^pool, _reason}, 300
    assert Process.alive?(pool)

    :ok = poll_until(fn -> worker not in connection_pids(pool) end)

    assert {:ok, %{status: 200}} = Pool.request(pool, :get, "/", [], nil, receive_timeout: 5_000)
  end
end
