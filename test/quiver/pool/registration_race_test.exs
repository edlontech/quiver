defmodule Quiver.Pool.RegistrationRaceTest do
  use ExUnit.Case, async: false
  @moduletag :integration

  alias Quiver.H3TestServer
  alias Quiver.Pool.HTTP2
  alias Quiver.Pool.HTTP3
  alias Quiver.Pool.Manager
  alias Quiver.TestServer

  describe "HTTP/3 pool init/Registry ordering" do
    setup do
      {:ok, server} =
        H3TestServer.start(fn h3_conn, sid, _m, _p, _h ->
          :quic_h3.send_response(h3_conn, sid, 200, [])
          :quic_h3.send_data(h3_conn, sid, "ok", true)
        end)

      on_exit(fn -> H3TestServer.stop(server.name) end)
      {:ok, server: server}
    end

    test "persistent_term marker is set the moment the pool appears in Registry", %{
      server: server
    } do
      name = :"reg_race_h3_#{System.unique_integer([:positive])}"

      start_supervised!(
        {Quiver.Supervisor,
         name: name,
         pools: %{
           default: [protocol: :http3, verify: :verify_none, cacerts: server.cacerts]
         }}
      )

      origin = {:https, "localhost", server.port}

      {:ok, pid} = Manager.get_pool(name, origin)

      registry = Quiver.Supervisor.registry_name(name)
      assert [{^pid, _}] = Registry.lookup(registry, origin)
      assert :persistent_term.get({HTTP3, pid}, nil) == true
    end

    test "the protocol marker is set before the pool is ever exposed via Registry", %{
      server: server
    } do
      # Drive the race deterministically by observing the pool from a separate
      # process while the gen_statem is being started. The bug pre-fix shape is:
      # via-registration happens BEFORE init/1 runs, so a watcher process can
      # see the pid in Registry while persistent_term still has no entry. With
      # the fix, init/1 publishes the marker before registering the name, so
      # the two states are guaranteed consistent from every observer.
      name = :"reg_race_h3_obs_#{System.unique_integer([:positive])}"

      start_supervised!(
        {Quiver.Supervisor,
         name: name,
         pools: %{
           default: [protocol: :http3, verify: :verify_none, cacerts: server.cacerts]
         }}
      )

      origin = {:https, "localhost", server.port}
      registry = Quiver.Supervisor.registry_name(name)
      test_pid = self()

      observer =
        spawn_link(fn ->
          observe_loop(registry, origin, test_pid, 5_000)
        end)

      {:ok, pid} = Manager.get_pool(name, origin)
      send(observer, :stop)

      observations =
        receive do
          {:observations, list} -> list
        after
          5_000 -> flunk("observer never reported observations")
        end

      bad =
        Enum.filter(observations, fn {found_pid, marker} ->
          found_pid == pid and marker == nil
        end)

      assert bad == [],
             "observer saw pool in Registry without persistent_term marker: #{inspect(bad)}"
    end

    test "concurrent first-touch from many callers all resolve to the HTTP/3 pool module",
         %{server: server} do
      name = :"reg_race_h3_burst_#{System.unique_integer([:positive])}"

      start_supervised!(
        {Quiver.Supervisor,
         name: name,
         pools: %{
           default: [protocol: :http3, verify: :verify_none, cacerts: server.cacerts]
         }}
      )

      results =
        1..50
        |> Task.async_stream(
          fn _ ->
            Quiver.new(:get, "https://localhost:#{server.port}/x")
            |> Quiver.request(name: name, receive_timeout: 10_000)
          end,
          max_concurrency: 20,
          timeout: 15_000,
          ordered: false
        )
        |> Enum.to_list()

      assert Enum.all?(results, fn
               {:ok, {:ok, %Quiver.Response{status: 200}}} -> true
               _ -> false
             end),
             "expected all 50 concurrent requests to dispatch via HTTP/3; got: " <>
               inspect(
                 Enum.reject(results, &match?({:ok, {:ok, %Quiver.Response{status: 200}}}, &1))
               )
    end
  end

  describe "HTTP/2 pool init/Registry ordering" do
    test "persistent_term marker is set the moment the pool appears in Registry" do
      {:ok, server} =
        TestServer.start(fn conn -> Plug.Conn.send_resp(conn, 200, "h2") end,
          https: true,
          http_2_only: true
        )

      on_exit(fn -> TestServer.stop(server) end)

      %{port: port, cacerts: cacerts} = server
      name = :"reg_race_h2_#{System.unique_integer([:positive])}"

      start_supervised!(
        {Quiver.Supervisor,
         name: name,
         pools: %{
           default: [protocol: :http2, verify: :verify_none, cacerts: cacerts]
         }}
      )

      origin = {:https, "127.0.0.1", port}
      {:ok, pid} = Manager.get_pool(name, origin)

      registry = Quiver.Supervisor.registry_name(name)
      assert [{^pid, _}] = Registry.lookup(registry, origin)
      assert :persistent_term.get({HTTP2, pid}, nil) == true
    end
  end

  defp observe_loop(registry, origin, test_pid, deadline_ms) do
    deadline = System.monotonic_time(:millisecond) + deadline_ms
    do_observe_loop(registry, origin, test_pid, deadline, [])
  end

  defp do_observe_loop(registry, origin, test_pid, deadline, acc) do
    receive do
      :stop ->
        send(test_pid, {:observations, Enum.reverse(acc)})
    after
      0 ->
        sample =
          case Registry.lookup(registry, origin) do
            [{pid, _}] -> {pid, :persistent_term.get({HTTP3, pid}, nil)}
            [] -> {nil, nil}
          end

        acc = [sample | acc]

        if System.monotonic_time(:millisecond) > deadline do
          send(test_pid, {:observations, Enum.reverse(acc)})
        else
          do_observe_loop(registry, origin, test_pid, deadline, acc)
        end
    end
  end

  describe "persistent_term cleanup on terminate" do
    test "HTTP/3 erases its persistent_term entry when the pool stops cleanly" do
      {:ok, server} =
        H3TestServer.start(fn h3_conn, sid, _m, _p, _h ->
          :quic_h3.send_response(h3_conn, sid, 200, [])
          :quic_h3.send_data(h3_conn, sid, "ok", true)
        end)

      on_exit(fn -> H3TestServer.stop(server.name) end)

      {:ok, pool} =
        HTTP3.start_link(
          origin: {:https, "localhost", server.port},
          pool_opts: [verify: :verify_none, cacerts: server.cacerts]
        )

      assert :persistent_term.get({HTTP3, pool}, nil) == true

      ref = Process.monitor(pool)
      :ok = GenStateMachine.stop(pool, :normal, 1_000)
      assert_receive {:DOWN, ^ref, :process, ^pool, :normal}, 1_000

      assert :persistent_term.get({HTTP3, pool}, nil) == nil
    end
  end
end
