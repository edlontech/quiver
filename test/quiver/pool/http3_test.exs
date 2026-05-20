defmodule Quiver.Pool.HTTP3Test do
  use ExUnit.Case, async: false
  @moduletag :integration

  alias Quiver.Error.CheckoutTimeout
  alias Quiver.H3TestServer
  alias Quiver.Pool.HTTP3
  alias Quiver.Response

  setup do
    handler = fn h3_conn, sid, _method, _path, _headers ->
      :quic_h3.send_response(h3_conn, sid, 200, [])
      :quic_h3.send_data(h3_conn, sid, "ok", true)
    end

    {:ok, server} = H3TestServer.start(handler)
    on_exit(fn -> H3TestServer.stop(server.name) end)

    {:ok, server: server, config: [verify: :verify_none, cacerts: server.cacerts]}
  end

  test "request through coordinator returns Response", %{server: server, config: config} do
    {:ok, pool} =
      HTTP3.start_link(origin: {:https, "localhost", server.port}, pool_opts: config)

    assert {:ok, %Response{status: 200, body: "ok"}} =
             HTTP3.request(pool, :get, "/", [], nil, receive_timeout: 5_000)
  end

  test "concurrent requests on the same connection", %{server: server, config: config} do
    {:ok, pool} =
      HTTP3.start_link(origin: {:https, "localhost", server.port}, pool_opts: config)

    tasks =
      for _ <- 1..10 do
        Task.async(fn ->
          HTTP3.request(pool, :get, "/", [], nil, receive_timeout: 5_000)
        end)
      end

    results = Task.await_many(tasks, 10_000)
    assert Enum.all?(results, &match?({:ok, %Response{status: 200}}, &1))

    stats = HTTP3.stats(pool)
    assert stats.connections == 1
  end

  test "stats reflect connection count after request", %{server: server, config: config} do
    {:ok, pool} =
      HTTP3.start_link(origin: {:https, "localhost", server.port}, pool_opts: config)

    assert %{connections: 0, active: 0, queued: 0} = HTTP3.stats(pool)

    {:ok, _} = HTTP3.request(pool, :get, "/", [], nil, receive_timeout: 5_000)

    stats = HTTP3.stats(pool)
    assert stats.connections >= 1
    assert stats.active == 0
    assert stats.queued == 0
  end

  test "self-registers in persistent_term for Manager protocol detection", %{
    server: server,
    config: config
  } do
    {:ok, pool} =
      HTTP3.start_link(origin: {:https, "localhost", server.port}, pool_opts: config)

    assert :persistent_term.get({HTTP3, pool}, nil) == true
  end

  test "expands to max_connections under concurrent load", %{server: server, config: config} do
    pool_opts =
      config
      |> Keyword.put(:max_connections, 3)
      |> Keyword.put(:initial_max_streams, 2)

    {:ok, pool} =
      HTTP3.start_link(origin: {:https, "localhost", server.port}, pool_opts: pool_opts)

    tasks =
      for _ <- 1..12 do
        Task.async(fn ->
          HTTP3.request(pool, :get, "/", [], nil, receive_timeout: 10_000)
        end)
      end

    results = Task.await_many(tasks, 15_000)
    assert Enum.all?(results, &match?({:ok, %Response{status: 200}}, &1))

    stats = HTTP3.stats(pool)
    assert stats.connections >= 2
    assert stats.connections <= 3
  end

  test "queues when all slots saturated and dequeues as streams finish", %{
    server: server,
    config: config
  } do
    pool_opts =
      config
      |> Keyword.put(:max_connections, 1)
      |> Keyword.put(:initial_max_streams, 4)

    {:ok, pool} =
      HTTP3.start_link(origin: {:https, "localhost", server.port}, pool_opts: pool_opts)

    tasks =
      for _ <- 1..50 do
        Task.async(fn ->
          HTTP3.request(pool, :get, "/", [], nil, receive_timeout: 10_000)
        end)
      end

    results = Task.await_many(tasks, 30_000)
    assert Enum.all?(results, &match?({:ok, %Response{status: 200}}, &1))

    stats = HTTP3.stats(pool)
    assert stats.connections == 1
    assert stats.queued == 0
  end

  test "checkout timeout fires when queue cannot be served" do
    slow_handler = fn h3_conn, sid, _method, _path, _headers ->
      Process.sleep(2_000)
      :quic_h3.send_response(h3_conn, sid, 200, [])
      :quic_h3.send_data(h3_conn, sid, "ok", true)
    end

    {:ok, slow_server} = H3TestServer.start(slow_handler)
    on_exit(fn -> H3TestServer.stop(slow_server.name) end)

    pool_opts = [
      verify: :verify_none,
      cacerts: slow_server.cacerts,
      max_connections: 1,
      initial_max_streams: 1,
      checkout_timeout: 250
    ]

    {:ok, pool} =
      HTTP3.start_link(origin: {:https, "localhost", slow_server.port}, pool_opts: pool_opts)

    blocker =
      Task.async(fn ->
        HTTP3.request(pool, :get, "/slow", [], nil, receive_timeout: 30_000)
      end)

    Process.sleep(150)

    result =
      HTTP3.request(pool, :get, "/", [], nil,
        receive_timeout: 30_000,
        checkout_timeout: 250
      )

    assert {:error, %CheckoutTimeout{}} = result

    _ = Task.shutdown(blocker, :brutal_kill)
  end
end
