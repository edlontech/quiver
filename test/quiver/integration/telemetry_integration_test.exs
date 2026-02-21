defmodule Quiver.Integration.TelemetryIntegrationTest do
  use ExUnit.Case, async: false

  alias Quiver.Pool.HTTP1, as: PoolHTTP1
  alias Quiver.TestServer

  import Quiver.TestCase.Integration, only: [poll_until: 1]

  def handle_telemetry(event, measurements, metadata, pid) do
    send(pid, {:telemetry, event, measurements, metadata})
  end

  setup do
    name = :"telemetry_#{System.unique_integer([:positive])}"

    {:ok, %{port: port} = server} =
      TestServer.start(fn conn -> Plug.Conn.send_resp(conn, 200, "ok") end)

    {:ok, _} = Quiver.Supervisor.start_link(name: name, pools: %{default: []})

    parent = self()
    ref = make_ref()

    :telemetry.attach_many(
      "test-#{inspect(ref)}",
      [
        [:quiver, :request, :start],
        [:quiver, :request, :stop],
        [:quiver, :request, :exception],
        [:quiver, :conn, :start],
        [:quiver, :conn, :stop]
      ],
      &__MODULE__.handle_telemetry/4,
      parent
    )

    on_exit(fn ->
      TestServer.stop(server)
      :telemetry.detach("test-#{inspect(ref)}")
    end)

    %{name: name, port: port}
  end

  test "emits request start and stop span", %{name: name, port: port} do
    assert {:ok, %Quiver.Response{status: 200}} =
             Quiver.new(:get, "http://127.0.0.1:#{port}/test")
             |> Quiver.request(name)

    assert_received {:telemetry, [:quiver, :request, :start], %{system_time: _}, meta}
    assert meta.name == name
    assert %Quiver.Request{} = meta.request

    assert_received {:telemetry, [:quiver, :request, :stop], %{duration: duration}, meta}
    assert duration > 0
    assert meta.name == name
  end

  test "emits conn start and stop for fresh connection", %{name: name, port: port} do
    assert {:ok, _} =
             Quiver.new(:get, "http://127.0.0.1:#{port}/test")
             |> Quiver.request(name)

    assert_received {:telemetry, [:quiver, :conn, :start], %{system_time: _}, meta}
    assert meta.origin == {:http, "127.0.0.1", port}

    assert_received {:telemetry, [:quiver, :conn, :stop], %{duration: duration}, meta}
    assert duration > 0
    assert meta.origin == {:http, "127.0.0.1", port}
  end

  test "does not emit conn span for reused connection", %{name: name, port: port} do
    url = "http://127.0.0.1:#{port}/test"

    assert {:ok, _} = Quiver.new(:get, url) |> Quiver.request(name)

    assert_received {:telemetry, [:quiver, :conn, :start], _, _}
    assert_received {:telemetry, [:quiver, :conn, :stop], _, _}

    poll_until(fn ->
      {:ok, stats} = Quiver.pool_stats(name, url)
      stats.idle >= 1
    end)

    assert {:ok, _} = Quiver.new(:get, url) |> Quiver.request(name)

    assert_received {:telemetry, [:quiver, :request, :start], _, _}
    assert_received {:telemetry, [:quiver, :request, :stop], _, _}
    refute_received {:telemetry, [:quiver, :conn, :start], _, _}
  end

  test "emits conn:close on idle timeout eviction" do
    parent = self()
    ref = make_ref()

    :telemetry.attach(
      "close-#{inspect(ref)}",
      [:quiver, :conn, :close],
      &__MODULE__.handle_telemetry/4,
      parent
    )

    {:ok, %{port: port} = server} =
      TestServer.start(fn conn -> Plug.Conn.send_resp(conn, 200, "ok") end)

    {:ok, pool} =
      PoolHTTP1.start_link(
        origin: {:http, "127.0.0.1", port},
        pool_opts: [idle_timeout: 200, ping_interval: 100]
      )

    assert {:ok, _} = PoolHTTP1.request(pool, :get, "/", [], nil)

    assert_receive {:telemetry, [:quiver, :conn, :close], %{system_time: _},
                    %{reason: :idle_timeout}},
                   3_000

    GenServer.stop(pool)

    TestServer.stop(server)
    :telemetry.detach("close-#{inspect(ref)}")
  end
end
