defmodule Quiver.Pool.HTTP3ResilienceTest do
  use ExUnit.Case, async: false
  use AssertEventually, timeout: 2_000, interval: 25
  @moduletag :integration

  alias Quiver.Error.H3GoAway
  alias Quiver.Error.QUICTransportError
  alias Quiver.H3TestServer
  alias Quiver.Pool.HTTP3
  alias Quiver.Response

  defp attach_h3_telemetry(events) do
    test_pid = self()
    id = "h3-resilience-#{System.unique_integer([:positive])}"

    handler_fn = fn evt, meas, meta, _ ->
      send(test_pid, {:tel, evt, meas, meta})
    end

    :ok = :telemetry.attach_many(id, events, handler_fn, nil)
    on_exit(fn -> :telemetry.detach(id) end)
    id
  end

  defp pool_connections(pool) do
    pool
    |> :sys.get_state()
    |> elem(1)
    |> Map.fetch!(:connections)
    |> Map.to_list()
  end

  defp wait_for_connection(pool) do
    assert_eventually(match?([_ | _], pool_connections(pool)))
    [{conn_pid, _info} | _] = pool_connections(pool)
    conn_pid
  end

  defp wait_for_inflight_request(pool) do
    assert_eventually(
      case pool_connections(pool) do
        [{pid, _} | _] ->
          case :sys.get_state(pid) do
            {_state, %{requests: r}} -> map_size(r) > 0
            _ -> false
          end

        _ ->
          false
      end
    )
  end

  describe "GOAWAY drain" do
    setup do
      handler = fn h3_conn, sid, _method, _path, _headers ->
        :quic_h3.send_response(h3_conn, sid, 200, [])
        :quic_h3.send_data(h3_conn, sid, "ok", true)
      end

      {:ok, server} = H3TestServer.start(handler)
      on_exit(fn -> H3TestServer.stop(server.name) end)

      {:ok, server: server, config: [verify: :verify_none, cacerts: server.cacerts]}
    end

    test "synthetic GOAWAY drains connection and routes future requests to fresh one", %{
      server: server,
      config: config
    } do
      pool_opts = Keyword.put(config, :max_connections, 2)

      {:ok, pool} =
        HTTP3.start_link(origin: {:https, "localhost", server.port}, pool_opts: pool_opts)

      assert {:ok, %Response{status: 200}} =
               HTTP3.request(pool, :get, "/", [], nil, receive_timeout: 5_000)

      [{conn_pid, _info}] = pool_connections(pool)

      %{h3_conn: h3_conn} = :sys.get_state(conn_pid) |> elem(1)

      conn_mon = Process.monitor(conn_pid)
      send(conn_pid, {:quic_h3, h3_conn, {:goaway, 1_000_000}})

      assert_receive {:DOWN, ^conn_mon, :process, ^conn_pid, :normal}, 1_000
      refute Process.alive?(conn_pid)

      assert {:ok, %Response{status: 200}} =
               HTTP3.request(pool, :get, "/", [], nil, receive_timeout: 5_000)
    end

    test "GOAWAY kills streaming body task for abandoned unprocessed stream" do
      slow_handler = fn _h3_conn, _sid, _method, _path, _headers ->
        Process.sleep(5_000)
      end

      {:ok, slow_server} = H3TestServer.start(slow_handler)
      on_exit(fn -> H3TestServer.stop(slow_server.name) end)

      slow_config = [verify: :verify_none, cacerts: slow_server.cacerts]

      {:ok, pool} =
        HTTP3.start_link(
          origin: {:https, "localhost", slow_server.port},
          pool_opts: slow_config
        )

      body_stream =
        Stream.repeatedly(fn ->
          Process.sleep(20)
          "chunk|"
        end)
        |> Stream.take(10_000)

      caller =
        Task.async(fn ->
          HTTP3.request(
            pool,
            :post,
            "/sink",
            [{"content-type", "text/plain"}],
            {:stream, body_stream},
            receive_timeout: 10_000
          )
        end)

      conn_pid = wait_for_stream_task(pool, 100)

      [{_ref, task_pid}] =
        Map.to_list(:sys.get_state(conn_pid) |> elem(1) |> Map.fetch!(:stream_tasks))

      assert Process.alive?(task_pid)

      %{h3_conn: h3_conn} = :sys.get_state(conn_pid) |> elem(1)
      task_mon = Process.monitor(task_pid)

      send(conn_pid, {:quic_h3, h3_conn, {:goaway, 0}})

      assert {:error, %H3GoAway{unprocessed_stream: true}} = Task.await(caller, 5_000)
      assert_receive {:DOWN, ^task_mon, :process, ^task_pid, _reason}, 1_000
      refute Process.alive?(task_pid)

      if Process.alive?(conn_pid) do
        {_state, data} = :sys.get_state(conn_pid)
        assert data.stream_tasks == %{}
        assert data.requests == %{}
      end
    end

    test "GOAWAY that drains the last in-flight request still routes through :draining and notifies the pool" do
      slow_handler = fn _h3_conn, _sid, _method, _path, _headers ->
        Process.sleep(5_000)
      end

      {:ok, slow_server} = H3TestServer.start(slow_handler)
      on_exit(fn -> H3TestServer.stop(slow_server.name) end)

      slow_config = [verify: :verify_none, cacerts: slow_server.cacerts]

      attach_h3_telemetry([[:quiver, :connection, :http3, :draining]])

      {:ok, pool} =
        HTTP3.start_link(
          origin: {:https, "localhost", slow_server.port},
          pool_opts: slow_config
        )

      caller =
        Task.async(fn ->
          HTTP3.request(pool, :get, "/", [], nil, receive_timeout: 5_000)
        end)

      wait_for_inflight_request(pool)

      [{conn_pid, _info} | _] = pool_connections(pool)
      conn_mon = Process.monitor(conn_pid)
      %{h3_conn: h3_conn} = :sys.get_state(conn_pid) |> elem(1)

      send(conn_pid, {:quic_h3, h3_conn, {:goaway, 0}})

      assert {:error, %H3GoAway{unprocessed_stream: true}} = Task.await(caller, 2_000)

      assert_receive {:tel, [:quiver, :connection, :http3, :draining], _, %{last_stream_id: 0}},
                     1_000

      assert_receive {:DOWN, ^conn_mon, :process, ^conn_pid, :normal}, 1_000

      [{_pid, %{state: pool_state}}] =
        case pool_connections(pool) do
          [] -> [{nil, %{state: :removed}}]
          conns -> conns
        end

      assert pool_state in [:draining, :removed]
    end

    test "forward_request arriving after GOAWAY-drained-everything is rejected, not lost" do
      slow_handler = fn _h3_conn, _sid, _method, _path, _headers ->
        Process.sleep(5_000)
      end

      {:ok, slow_server} = H3TestServer.start(slow_handler)
      on_exit(fn -> H3TestServer.stop(slow_server.name) end)

      slow_config = [verify: :verify_none, cacerts: slow_server.cacerts]

      {:ok, pool} =
        HTTP3.start_link(
          origin: {:https, "localhost", slow_server.port},
          pool_opts: slow_config
        )

      caller =
        Task.async(fn ->
          HTTP3.request(pool, :get, "/", [], nil, receive_timeout: 5_000)
        end)

      wait_for_inflight_request(pool)

      [{conn_pid, _info} | _] = pool_connections(pool)
      %{h3_conn: h3_conn} = :sys.get_state(conn_pid) |> elem(1)

      send(conn_pid, {:quic_h3, h3_conn, {:goaway, 0}})

      assert {:error, %H3GoAway{}} = Task.await(caller, 2_000)

      reply_ref = make_ref()
      send(conn_pid, {:forward_request, {self(), reply_ref}, :get, "/", [], nil, 5_000})

      assert_receive {^reply_ref, {:error, %H3GoAway{}}}, 1_000
    end

    test "draining worker with in-flight request rejects new forwards with H3GoAway" do
      slow_handler = fn h3_conn, sid, _method, _path, _headers ->
        Process.sleep(500)
        :quic_h3.send_response(h3_conn, sid, 200, [])
        :quic_h3.send_data(h3_conn, sid, "ok", true)
      end

      {:ok, slow_server} = H3TestServer.start(slow_handler)
      on_exit(fn -> H3TestServer.stop(slow_server.name) end)

      slow_config = [verify: :verify_none, cacerts: slow_server.cacerts]

      attach_h3_telemetry([[:quiver, :connection, :http3, :draining]])

      {:ok, pool} =
        HTTP3.start_link(
          origin: {:https, "localhost", slow_server.port},
          pool_opts: slow_config
        )

      inflight =
        Task.async(fn ->
          HTTP3.request(pool, :get, "/", [], nil, receive_timeout: 5_000)
        end)

      wait_for_inflight_request(pool)

      [{conn_pid, _info} | _] = pool_connections(pool)

      %{h3_conn: h3_conn} = :sys.get_state(conn_pid) |> elem(1)

      send(conn_pid, {:quic_h3, h3_conn, {:goaway, 1_000_000}})

      assert_receive {:tel, [:quiver, :connection, :http3, :draining], _,
                      %{last_stream_id: 1_000_000}},
                     1_000

      assert Process.alive?(conn_pid)
      {state, data} = :sys.get_state(conn_pid)
      assert state == :draining
      assert data.goaway_id == 1_000_000

      reply_ref = make_ref()
      send(conn_pid, {:forward_request, {self(), reply_ref}, :get, "/", [], nil, 5_000})

      assert_receive {^reply_ref, {:error, %Quiver.Error.H3GoAway{}}}, 1_000

      assert {:ok, _} = Task.await(inflight, 5_000)
    end
  end

  describe "caller cancellation" do
    setup do
      handler = fn h3_conn, sid, _method, _path, _headers ->
        Process.sleep(2_000)
        :quic_h3.send_response(h3_conn, sid, 200, [])
        :quic_h3.send_data(h3_conn, sid, "ok", true)
      end

      {:ok, server} = H3TestServer.start(handler)
      on_exit(fn -> H3TestServer.stop(server.name) end)

      {:ok, server: server, config: [verify: :verify_none, cacerts: server.cacerts]}
    end

    test "caller process death cancels stream and decrements active count", %{
      server: server,
      config: config
    } do
      {:ok, pool} =
        HTTP3.start_link(origin: {:https, "localhost", server.port}, pool_opts: config)

      caller =
        Task.async(fn ->
          HTTP3.request(pool, :get, "/slow", [], nil, receive_timeout: 30_000)
        end)

      assert_eventually(HTTP3.stats(pool).active >= 1)

      _ = Task.shutdown(caller, :brutal_kill)

      assert_eventually(HTTP3.stats(pool).active == 0)
    end
  end

  describe "abrupt connection close" do
    test "in-flight request fails with QUICTransportError on transport :closed event" do
      handler = fn h3_conn, sid, _method, _path, _headers ->
        Process.sleep(3_000)
        :quic_h3.send_response(h3_conn, sid, 200, [])
        :quic_h3.send_data(h3_conn, sid, "late", true)
      end

      {:ok, server} = H3TestServer.start(handler)
      on_exit(fn -> H3TestServer.stop(server.name) end)

      {:ok, pool} =
        HTTP3.start_link(
          origin: {:https, "localhost", server.port},
          pool_opts: [verify: :verify_none, cacerts: server.cacerts]
        )

      caller =
        Task.async(fn ->
          HTTP3.request(pool, :get, "/slow", [], nil, receive_timeout: 10_000)
        end)

      assert_eventually(HTTP3.stats(pool).active >= 1)

      conn_pid = wait_for_connection(pool)
      %{h3_conn: h3_conn} = :sys.get_state(conn_pid) |> elem(1)

      send(conn_pid, {:quic_h3, h3_conn, :closed})

      result = Task.await(caller, 5_000)
      assert {:error, %QUICTransportError{}} = result
    end

    test "in-flight request fails with QUICTransportError on transport error event" do
      Process.flag(:trap_exit, true)

      handler = fn h3_conn, sid, _method, _path, _headers ->
        Process.sleep(3_000)
        :quic_h3.send_response(h3_conn, sid, 200, [])
        :quic_h3.send_data(h3_conn, sid, "late", true)
      end

      {:ok, server} = H3TestServer.start(handler)
      on_exit(fn -> H3TestServer.stop(server.name) end)

      {:ok, pool} =
        HTTP3.start_link(
          origin: {:https, "localhost", server.port},
          pool_opts: [verify: :verify_none, cacerts: server.cacerts]
        )

      caller =
        Task.async(fn ->
          HTTP3.request(pool, :get, "/slow", [], nil, receive_timeout: 10_000)
        end)

      assert_eventually(HTTP3.stats(pool).active >= 1)

      conn_pid = wait_for_connection(pool)
      %{h3_conn: h3_conn} = :sys.get_state(conn_pid) |> elem(1)

      send(conn_pid, {:quic_h3, h3_conn, {:error, 0x10C, :application_error}})

      result = Task.await(caller, 5_000)
      assert {:error, %QUICTransportError{code: 0x10C}} = result
    end
  end

  defp wait_for_stream_task(pool, attempts) when attempts > 0 do
    case pool_connections(pool) do
      [{conn_pid, _info} | _] ->
        case :sys.get_state(conn_pid) do
          {_state, %{stream_tasks: tasks}} when map_size(tasks) > 0 ->
            conn_pid

          _ ->
            Process.sleep(20)
            wait_for_stream_task(pool, attempts - 1)
        end

      [] ->
        Process.sleep(20)
        wait_for_stream_task(pool, attempts - 1)
    end
  end

  defp wait_for_stream_task(_pool, 0),
    do: flunk("timed out waiting for stream task to be tracked")
end
