defmodule Quiver.HTTP3.DatagramsTest do
  use Quiver.TestCase.Integration, async: false

  @moduletag :integration

  alias Quiver.Error.H3DatagramError
  alias Quiver.Error.H3DatagramsDisabled
  alias Quiver.HTTP3
  alias Quiver.HTTP3.Channel
  alias Quiver.Pool.HTTP3, as: PoolHTTP3
  alias Quiver.Pool.HTTP3.Connection, as: PoolHTTP3Connection
  alias Quiver.Supervisor, as: QuiverSupervisor
  alias Quiver.Test.H3DatagramTestServer

  setup do
    {:ok, server} = H3DatagramTestServer.start()
    on_exit(fn -> H3DatagramTestServer.stop(server) end)

    sup_name = :"datagrams_client_#{System.unique_integer([:positive])}"

    start_supervised!(
      Supervisor.child_spec(
        {QuiverSupervisor,
         name: sup_name,
         pools: %{
           :default => [
             protocol: :http3,
             verify: :verify_none,
             cacerts: server.cacerts,
             max_connections: 1
           ]
         }},
        id: sup_name
      )
    )

    %{server: server, sup_name: sup_name, port: server.port}
  end

  describe "open_datagram_channel/4 lifecycle" do
    test "returns final acc on normal close (extended CONNECT 4xx)", %{
      port: port,
      sup_name: sup_name
    } do
      assert {:ok, {:rejected, 403, :peer}} =
               HTTP3.open_datagram_channel(
                 "https://localhost:#{port}/reject",
                 [name: sup_name, method: :get],
                 fn
                   {:response, 403, _hs}, _ch, _acc -> {:cont, 403}
                   {:closed, reason}, _ch, 403 -> {:halt, {:rejected, 403, reason}}
                   _, _, acc -> {:cont, acc}
                 end,
                 nil
               )
    end

    test "non-2xx response delivered, handler halts", %{port: port, sup_name: sup_name} do
      assert {:ok, 403} =
               HTTP3.open_datagram_channel(
                 "https://localhost:#{port}/reject",
                 [name: sup_name],
                 fn
                   {:response, status, _hs}, _ch, _acc -> {:halt, status}
                   _, _, acc -> {:cont, acc}
                 end,
                 nil
               )
    end

    test ":datagram before :response delivered with channel.status == nil", %{
      port: port,
      sup_name: sup_name
    } do
      assert {:ok, :ok} =
               HTTP3.open_datagram_channel(
                 "https://localhost:#{port}/pre-response-datagram",
                 [name: sup_name],
                 fn
                   {:datagram, "early"}, %Channel{status: nil}, _acc -> {:halt, :ok}
                   _, _, acc -> {:cont, acc}
                 end,
                 nil
               )
    end
  end

  describe "send_datagram/2" do
    test "round-trips through /echo", %{port: port, sup_name: sup_name} do
      assert {:ok, "ping"} =
               HTTP3.open_datagram_channel(
                 "https://localhost:#{port}/echo",
                 [name: sup_name],
                 fn
                   {:response, 200, _}, ch, _ ->
                     :ok = HTTP3.send_datagram(ch, "ping")
                     {:cont, nil}

                   {:datagram, payload}, _ch, _acc ->
                     {:halt, payload}

                   {:closed, _}, _, _ ->
                     {:halt, :closed_unexpectedly}
                 end,
                 nil
               )
    end

    test "oversize payload returns H3DatagramError(:too_large) with :invalid class", %{
      port: port,
      sup_name: sup_name
    } do
      assert {:ok, {:error, %H3DatagramError{reason: :too_large} = err}} =
               HTTP3.open_datagram_channel(
                 "https://localhost:#{port}/big",
                 [name: sup_name],
                 fn
                   {:response, 200, _}, ch, _ ->
                     oversize = :binary.copy(<<0>>, 100_000)
                     {:halt, HTTP3.send_datagram(ch, oversize)}

                   _, _, acc ->
                     {:cont, acc}
                 end,
                 nil
               )

      assert err.class == :invalid
    end

    test "after {:closed, _}, send_datagram is a benign no-op or :transient error", %{
      port: port,
      sup_name: sup_name
    } do
      {:ok, ch} =
        HTTP3.open_datagram_channel(
          "https://localhost:#{port}/reject",
          [name: sup_name],
          fn
            {:response, 403, _}, ch, _ -> {:cont, ch}
            {:closed, _}, _ch, captured -> {:halt, captured}
          end,
          nil
        )

      assert %Channel{} = ch
      Process.sleep(100)

      case HTTP3.send_datagram(ch, "after-close") do
        :ok ->
          # benign lifecycle race: :quic_h3 still has the stream tracked
          :ok

        {:error, %H3DatagramError{reason: :unknown_stream} = err} ->
          assert err.class == :transient

        {:error, %H3DatagramError{} = err} ->
          assert err.class == :transient

        {:error, %H3DatagramsDisabled{}} ->
          :ok
      end
    end
  end

  describe "max_datagram_size/1 and h3_datagrams_enabled?/1" do
    test "max_datagram_size returns non-zero after handshake on enabled server", %{
      port: port,
      sup_name: sup_name
    } do
      assert {:ok, size} =
               HTTP3.open_datagram_channel(
                 "https://localhost:#{port}/echo",
                 [name: sup_name],
                 fn
                   {:response, 200, _}, ch, _ -> {:halt, HTTP3.max_datagram_size(ch)}
                   _, _, acc -> {:cont, acc}
                 end,
                 nil
               )

      assert is_integer(size) and size > 0
    end

    test "h3_datagrams_enabled?/1 returns true on enabled server", %{
      port: port,
      sup_name: sup_name
    } do
      assert {:ok, true} =
               HTTP3.open_datagram_channel(
                 "https://localhost:#{port}/echo",
                 [name: sup_name],
                 fn
                   {:response, 200, _}, ch, _ -> {:halt, HTTP3.h3_datagrams_enabled?(ch)}
                   _, _, acc -> {:cont, acc}
                 end,
                 nil
               )
    end
  end

  describe "require_datagrams: true / disabled peer" do
    test "open returns H3DatagramsDisabled and drains queued events" do
      {:ok, server} = H3DatagramTestServer.start_no_datagrams()
      on_exit(fn -> H3DatagramTestServer.stop(server) end)

      sup_name = :"no_dg_client_#{System.unique_integer([:positive])}"

      start_supervised!(
        Supervisor.child_spec(
          {QuiverSupervisor,
           name: sup_name,
           pools: %{
             :default => [
               protocol: :http3,
               verify: :verify_none,
               cacerts: server.cacerts,
               max_connections: 1,
               h3_datagram_enabled: false
             ]
           }},
          id: sup_name
        )
      )

      assert {:error, %H3DatagramsDisabled{}} =
               HTTP3.open_datagram_channel(
                 "https://localhost:#{server.port}/echo",
                 [name: sup_name, require_datagrams: true],
                 fn _, _, _ -> {:halt, :unreached} end,
                 nil
               )

      refute_received {:quiver_h3_channel, _, _}
    end

    test "send_datagram returns H3DatagramsDisabled when peer didn't enable" do
      {:ok, server} = H3DatagramTestServer.start_no_datagrams()
      on_exit(fn -> H3DatagramTestServer.stop(server) end)

      sup_name = :"no_dg_send_client_#{System.unique_integer([:positive])}"

      start_supervised!(
        Supervisor.child_spec(
          {QuiverSupervisor,
           name: sup_name,
           pools: %{
             :default => [
               protocol: :http3,
               verify: :verify_none,
               cacerts: server.cacerts,
               max_connections: 1,
               h3_datagram_enabled: false
             ]
           }},
          id: sup_name
        )
      )

      assert {:ok, {:error, %H3DatagramsDisabled{}}} =
               HTTP3.open_datagram_channel(
                 "https://localhost:#{server.port}/echo",
                 [name: sup_name, require_datagrams: false],
                 fn
                   {:response, _, _}, ch, _ -> {:halt, HTTP3.send_datagram(ch, "ping")}
                   _, _, acc -> {:cont, acc}
                 end,
                 nil
               )
    end
  end

  describe ":halt and cancellation semantics" do
    test ":halt cancels the stream", %{port: port, sup_name: sup_name} do
      assert {:ok, :halted} =
               HTTP3.open_datagram_channel(
                 "https://localhost:#{port}/echo",
                 [name: sup_name],
                 fn
                   {:response, 200, _}, _, _ -> {:halt, :halted}
                   _, _, acc -> {:cont, acc}
                 end,
                 nil
               )
    end

    test "caller process death cancels and releases the pool slot", %{
      port: port,
      sup_name: sup_name
    } do
      pid =
        spawn(fn ->
          HTTP3.open_datagram_channel(
            "https://localhost:#{port}/slow",
            [name: sup_name, receive_timeout: 60_000],
            fn _, _, _ -> {:halt, :unreached} end,
            nil
          )
        end)

      Process.sleep(200)
      Process.exit(pid, :kill)
      Process.sleep(200)

      assert {:ok, "ping"} =
               HTTP3.open_datagram_channel(
                 "https://localhost:#{port}/echo",
                 [name: sup_name],
                 fn
                   {:response, 200, _}, ch, _ ->
                     :ok = HTTP3.send_datagram(ch, "ping")
                     {:cont, nil}

                   {:datagram, payload}, _, _ ->
                     {:halt, payload}

                   _, _, acc ->
                     {:cont, acc}
                 end,
                 nil
               )
    end

    test "receive_timeout fires per-event when no event arrives", %{
      port: port,
      sup_name: sup_name
    } do
      assert {:error, :recv_timeout} =
               HTTP3.open_datagram_channel(
                 "https://localhost:#{port}/slow",
                 [name: sup_name, receive_timeout: 200],
                 fn _, _, _ -> {:halt, :unreached} end,
                 nil
               )
    end
  end

  describe "connection-level events" do
    test "connection GOAWAY surfaces {:closed, {:goaway, _}}" do
      {:ok, server} = H3DatagramTestServer.start(:goaway_srv)
      on_exit(fn -> H3DatagramTestServer.stop(server) end)

      sup_name = :"goaway_dg_client_#{System.unique_integer([:positive])}"

      start_supervised!(
        Supervisor.child_spec(
          {QuiverSupervisor,
           name: sup_name,
           pools: %{
             :default => [
               protocol: :http3,
               verify: :verify_none,
               cacerts: server.cacerts,
               max_connections: 1
             ]
           }},
          id: sup_name
        )
      )

      test_pid = self()

      task =
        Task.async(fn ->
          HTTP3.open_datagram_channel(
            "https://localhost:#{server.port}/echo",
            [name: sup_name, receive_timeout: 5_000],
            fn
              {:response, 200, _hs}, ch, _ ->
                send(test_pid, {:opened, ch})
                {:cont, nil}

              {:closed, {:goaway, gid}}, _, _ ->
                {:halt, {:goaway, gid}}

              {:closed, other}, _, _ ->
                {:halt, {:closed, other}}

              _, _, acc ->
                {:cont, acc}
            end,
            nil
          )
        end)

      assert_receive {:opened, %Channel{worker_pid: worker_pid, h3_conn: h3_conn}}, 5_000

      send(worker_pid, {:quic_h3, h3_conn, {:goaway, 0}})

      assert {:ok, {:goaway, _gid}} = Task.await(task, 5_000)
    end

    test "connection death closes channel with {:closed, {:transport, _}}" do
      {:ok, server} = H3DatagramTestServer.start(:death_srv)
      on_exit(fn -> H3DatagramTestServer.stop(server) end)

      sup_name = :"death_dg_client_#{System.unique_integer([:positive])}"

      start_supervised!(
        Supervisor.child_spec(
          {QuiverSupervisor,
           name: sup_name,
           pools: %{
             :default => [
               protocol: :http3,
               verify: :verify_none,
               cacerts: server.cacerts,
               max_connections: 1
             ]
           }},
          id: sup_name
        )
      )

      test_pid = self()

      task =
        Task.async(fn ->
          HTTP3.open_datagram_channel(
            "https://localhost:#{server.port}/echo",
            [name: sup_name, receive_timeout: 5_000],
            fn
              {:response, 200, _}, ch, _ ->
                send(test_pid, {:opened, ch})
                {:cont, nil}

              {:closed, {:transport, exc}}, _, _ ->
                {:halt, {:transport, exc}}

              {:closed, other}, _, _ ->
                {:halt, {:closed, other}}

              _, _, acc ->
                {:cont, acc}
            end,
            nil
          )
        end)

      assert_receive {:opened, %Channel{h3_conn: h3_conn, worker_pid: worker_pid}}, 5_000

      # Inject a synthetic transport closure event into the worker; this
      # mirrors what happens when the QUIC connection fails (the worker
      # receives `{:quic_h3, h3_conn, :closed}` and fails all in-flight
      # requests with `QUICTransportError`).
      send(worker_pid, {:quic_h3, h3_conn, :closed})

      assert {:ok, {:transport, _exception}} = Task.await(task, 5_000)
    end
  end

  describe "concurrency" do
    test "multiple concurrent channels do not cross-talk", %{port: port, sup_name: sup_name} do
      tasks =
        for i <- 1..5 do
          Task.async(fn ->
            HTTP3.open_datagram_channel(
              "https://localhost:#{port}/echo",
              [name: sup_name, receive_timeout: 5_000],
              fn
                {:response, 200, _}, ch, _ ->
                  :ok = HTTP3.send_datagram(ch, "task-#{i}")
                  {:cont, nil}

                {:datagram, payload}, _ch, _ ->
                  {:halt, payload}

                _, _, acc ->
                  {:cont, acc}
              end,
              nil
            )
          end)
        end

      results = Task.await_many(tasks, 10_000)

      payloads =
        results
        |> Enum.map(fn {:ok, v} -> v end)
        |> Enum.sort()

      expected = 1..5 |> Enum.map(&"task-#{&1}") |> Enum.sort()
      assert payloads == expected
    end
  end

  describe "auto-negotiation (Task 2 coverage alias)" do
    test "pool with protocol: :http3 auto-enables h3_datagram_enabled", %{
      port: port,
      sup_name: sup_name
    } do
      origin = {:https, "localhost", port}
      registry = QuiverSupervisor.registry_name(sup_name)

      # Force pool creation.
      assert {:ok, _} =
               HTTP3.open_datagram_channel(
                 "https://localhost:#{port}/reject",
                 [name: sup_name],
                 fn
                   {:closed, _}, _, _ -> {:halt, :ok}
                   _, _, acc -> {:cont, acc}
                 end,
                 nil
               )

      poll_until(fn -> Registry.lookup(registry, origin) != [] end, 2_000)
      [{pool_pid, _}] = Registry.lookup(registry, origin)
      poll_until(fn -> PoolHTTP3.first_worker(pool_pid) != nil end, 2_000)
      worker = PoolHTTP3.first_worker(pool_pid)
      h3_conn = PoolHTTP3Connection.get_h3_conn(worker)
      assert :quic_h3.h3_datagrams_enabled(h3_conn) == true
    end
  end

  describe "telemetry" do
    test ":dropped fires for datagrams on non-:datagram_channel requests", %{
      port: port,
      sup_name: sup_name
    } do
      test_pid = self()
      id = "h3-dg-dropped-#{System.unique_integer([:positive])}"

      :telemetry.attach(
        id,
        [:quiver, :connection, :http3, :datagram, :dropped],
        fn _, meas, meta, _ -> send(test_pid, {:tel, :dropped, meas, meta}) end,
        nil
      )

      on_exit(fn -> :telemetry.detach(id) end)

      # A buffered GET to /sidechannel: the server sends a datagram during the
      # request (before END_STREAM). The worker has no :datagram_channel for
      # this stream id so the dispatch path emits :dropped.
      assert {:ok, _resp} =
               :get
               |> Quiver.new("https://localhost:#{port}/sidechannel")
               |> Quiver.request(name: sup_name)

      assert_receive {:tel, :dropped, _meas, %{reason: :wrong_mode}}, 2_000
    end
  end

  describe "extended CONNECT :protocol pseudo-header (Task 5)" do
    test "extended CONNECT with :protocol pseudo-header is sent in correct position" do
      {:ok, server} =
        H3DatagramTestServer.start(:h3_extconnect_srv,
          listener: self(),
          enable_connect_protocol: true
        )

      on_exit(fn -> H3DatagramTestServer.stop(server) end)

      sup_name = :"datagrams_extconnect_client_#{System.unique_integer([:positive])}"

      start_supervised!(
        Supervisor.child_spec(
          {QuiverSupervisor,
           name: sup_name,
           pools: %{
             :default => [
               protocol: :http3,
               verify: :verify_none,
               cacerts: server.cacerts,
               max_connections: 1,
               h3_settings: %{enable_connect_protocol: 1}
             ]
           }},
          id: sup_name
        )
      )

      assert {:ok, :seen} =
               HTTP3.open_datagram_channel(
                 "https://localhost:#{server.port}/extended-connect",
                 [
                   name: sup_name,
                   method: :connect,
                   protocol: "webtransport",
                   require_datagrams: false
                 ],
                 fn
                   {:response, 200, _hs}, _ch, _acc -> {:halt, :seen}
                   _, _, acc -> {:cont, acc}
                 end,
                 nil
               )

      assert_receive {:request_headers, "/extended-connect", method, headers}, 2_000

      method_str =
        case method do
          m when is_atom(m) -> m |> Atom.to_string() |> String.upcase()
          m when is_binary(m) -> String.upcase(m)
        end

      assert method_str == "CONNECT"

      # `:quic_h3` preserves pseudo-headers in the wire order delivered to the
      # handler (QPACK decoder yields fields in encoded order; see
      # `process_decoded_headers` / `notify_headers_received` in
      # `deps/quic/src/h3/quic_h3_connection.erl`). The unit test in
      # `test/quiver/conn/http3_test.exs` covers client-side ordering of the
      # full pseudo-header tuple; here we verify the wire arrival and the
      # relative position of `:protocol` vs `:scheme`.
      assert {":protocol", "webtransport"} in headers

      protocol_index = Enum.find_index(headers, fn {k, _} -> k == ":protocol" end)
      scheme_index = Enum.find_index(headers, fn {k, _} -> k == ":scheme" end)

      assert is_integer(protocol_index)
      assert is_integer(scheme_index)
      assert protocol_index < scheme_index
    end
  end

  describe "congestion-limited (skipped — requires pacing setup)" do
    @tag :skip
    test "send_datagram returns H3DatagramError(:congestion_limited) verbatim" do
      # Requires loading the congestion controller to closed state. Not
      # driveable with the simple H3DatagramTestServer fixture; skipping.
      flunk("Skipped: requires pacing/congestion setup beyond this fixture's scope")
    end
  end
end
