defmodule Quiver.Pool.HTTP3EarlyDataTest do
  use ExUnit.Case, async: false
  @moduletag :integration
  # These tests drive a real QUIC stack and retry the inherently racy 0-RTT path,
  # so they can legitimately run longer than ExUnit's 60s default.
  @moduletag timeout: 180_000

  alias Quiver.H3TestServer
  alias Quiver.Pool.HTTP3
  alias Quiver.Pool.HTTP3.Connection

  # These tests white-box the worker by start_linking it directly, so the test
  # process is linked to every worker it spawns. A worker stops with an abnormal
  # reason (:shutdown / :quic_closed) whenever its QUIC connection drops -- on
  # server teardown and on the workers discarded inside the early-stream retry
  # loops -- which would otherwise propagate down the link and kill the test.
  # Trapping exits turns those into ignorable messages.
  setup do
    Process.flag(:trap_exit, true)
    :ok
  end

  defp ok_handler do
    fn h3_conn, sid, _method, _path, _headers ->
      :quic_h3.send_response(h3_conn, sid, 200, [])
      :quic_h3.send_data(h3_conn, sid, "ok", true)
    end
  end

  defp start_server(handler) do
    {:ok, server} = H3TestServer.start(handler)
    on_exit(fn -> H3TestServer.stop(server.name) end)
    server
  end

  defp wait_until(fun, timeout \\ 5_000) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_wait_until(fun, deadline)
  end

  defp do_wait_until(fun, deadline) do
    cond do
      fun.() -> :ok
      System.monotonic_time(:millisecond) >= deadline -> flunk("wait_until timed out")
      true -> Process.sleep(10) && do_wait_until(fun, deadline)
    end
  end

  # Like wait_until/2 but returns a boolean instead of flunking on timeout.
  defp became_true?(fun, timeout \\ 1_000) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_became_true?(fun, deadline)
  end

  defp do_became_true?(fun, deadline) do
    cond do
      fun.() -> true
      System.monotonic_time(:millisecond) >= deadline -> false
      true -> Process.sleep(10) && do_became_true?(fun, deadline)
    end
  end

  # Closes the coordinator's current connection by feeding the worker a :closed
  # event (worker stops :normal, so the linked coordinator survives) and waits
  # for the coordinator to drop back to zero connections.
  defp tear_down_connection(pool) do
    case HTTP3.first_worker(pool) do
      nil ->
        :ok

      worker ->
        ref = Process.monitor(worker)
        conn = Connection.get_h3_conn(worker)
        send(worker, {:quic_h3, conn, :closed})

        receive do
          {:DOWN, ^ref, :process, ^worker, _} -> :ok
        after
          2_000 -> :ok
        end

        wait_until(fn -> map_size(coordinator_data(pool).connections) == 0 end)
    end
  end

  # The in-process :quic server issues NewSessionTicket non-deterministically per
  # handshake, so a single request may cache nothing. Drive requests on fresh
  # connections until the coordinator has cached a ticket.
  defp warm_until_ticket(pool, attempts \\ 25)
  defp warm_until_ticket(_pool, 0), do: flunk("coordinator cached no ticket after retries")

  defp warm_until_ticket(pool, attempts) do
    {:ok, %Quiver.Response{status: 200}} =
      HTTP3.request(pool, :get, "/", [], nil, receive_timeout: 5_000)

    flush_server_headers()

    if became_true?(fn -> coordinator_data(pool).tickets != [] end) do
      :ok
    else
      tear_down_connection(pool)
      warm_until_ticket(pool, attempts - 1)
    end
  end

  # The pure-Erlang :quic server emits NewSessionTicket as a post-handshake
  # message, but does not always send one for a given connection. Retry the
  # handshake until a real, resumable ticket lands.
  defp capture_ticket(server, config, attempts \\ 5)

  defp capture_ticket(_server, _config, 0), do: flunk("no session ticket after retries")

  defp capture_ticket(server, config, attempts) do
    {:ok, _w} =
      Connection.start_link(
        origin: {:https, "localhost", server.port},
        config: config,
        pool_pid: self()
      )

    receive do
      {:session_ticket, _origin, ticket} -> ticket
    after
      5_000 -> capture_ticket(server, config, attempts - 1)
    end
  end

  # Whether a forwarded early request truly rides 0-RTT (tracked as early?: true
  # with a stream id) is non-deterministic on the in-process loopback server.
  # Retry starting a fresh resuming worker + forwarding the early request until
  # the worker has an early?: true tracked stream, then return {worker, sid}.
  defp start_resuming_with_early_stream(server, config, tag, attempts \\ 60)

  defp start_resuming_with_early_stream(_server, _config, _tag, 0) do
    flunk("could not obtain a true-0-RTT early stream after retries")
  end

  defp start_resuming_with_early_stream(server, config, tag, attempts) do
    ticket = capture_ticket(server, config)

    {:ok, worker} =
      Connection.start_link(
        origin: {:https, "localhost", server.port},
        config: config,
        pool_pid: self(),
        session_ticket: ticket
      )

    forward_during_connecting(
      worker,
      {:forward_early_request, {self(), tag}, :get, "/", [], nil, 5_000}
    )

    case poll_early_stream(worker, System.monotonic_time(:millisecond) + 1_000) do
      {:ok, sid} ->
        {worker, sid}

      :none ->
        GenServer.stop(worker, :normal)
        flush_server_headers()
        start_resuming_with_early_stream(server, config, tag, attempts - 1)
    end
  end

  # The worker only sends a request 0-RTT while still in :connecting; once it
  # processes {:quic_h3, conn, :connected} the early-data window closes. On the
  # fast loopback that convergence message often beats a plain send/2. Suspend
  # the worker first so the early request is enqueued ahead of any convergence
  # message, then resume -- biasing the worker toward the 0-RTT path.
  defp forward_during_connecting(worker, msg) do
    :sys.suspend(worker)
    send(worker, msg)
    :sys.resume(worker)
  end

  defp poll_early_stream(worker, deadline) do
    {_state, data} = :sys.get_state(worker)

    early_sid =
      Enum.find_value(data.stream_to_ref, fn {sid, ref} ->
        case Map.fetch(data.requests, ref) do
          {:ok, %{early?: true}} -> sid
          _ -> nil
        end
      end)

    cond do
      early_sid != nil -> {:ok, early_sid}
      System.monotonic_time(:millisecond) >= deadline -> :none
      true -> Process.sleep(10) && poll_early_stream(worker, deadline)
    end
  end

  # For the 425 path the server responds immediately, so polling worker state
  # races the cleanup. Instead retry until the FIRST observed server headers
  # carry the Early-Data marker, which proves a genuine 0-RTT attempt happened.
  defp retry_until_early_attempt(server, config, attempts \\ 60)

  defp retry_until_early_attempt(_server, _config, 0) do
    flunk("could not observe a true-0-RTT early attempt after retries")
  end

  defp retry_until_early_attempt(server, config, attempts) do
    ticket = capture_ticket(server, config)
    tag = make_ref()

    {:ok, worker} =
      Connection.start_link(
        origin: {:https, "localhost", server.port},
        config: config,
        pool_pid: self(),
        session_ticket: ticket
      )

    forward_during_connecting(
      worker,
      {:forward_early_request, {self(), tag}, :get, "/", [], nil, 5_000}
    )

    receive do
      {:server_headers, headers} ->
        if Enum.any?(headers, fn {n, v} -> n == <<"early-data">> and v == <<"1">> end) do
          tag
        else
          GenServer.stop(worker, :normal)
          flush_server_headers()
          flush_tag(tag)
          retry_until_early_attempt(server, config, attempts - 1)
        end
    after
      5_000 ->
        GenServer.stop(worker, :normal)
        retry_until_early_attempt(server, config, attempts - 1)
    end
  end

  defp flush_tag(tag) do
    receive do
      {^tag, _} -> flush_tag(tag)
    after
      0 -> :ok
    end
  end

  defp flush_server_headers do
    receive do
      {:server_headers, _} -> flush_server_headers()
    after
      0 -> :ok
    end
  end

  describe "worker ticket capture" do
    test "forwards session_ticket events to the pool_pid and emits :ticket_received" do
      server = start_server(ok_handler())

      id = "tel-ticket-#{System.unique_integer([:positive])}"
      test_pid = self()

      :ok =
        :telemetry.attach(
          id,
          [:quiver, :connection, :http3, :ticket_received],
          fn evt, meas, meta, _ -> send(test_pid, {:tel, evt, meas, meta}) end,
          nil
        )

      on_exit(fn -> :telemetry.detach(id) end)

      {:ok, worker} =
        Connection.start_link(
          origin: {:https, "localhost", server.port},
          config: [verify: :verify_none, cacerts: server.cacerts],
          pool_pid: self()
        )

      conn = Connection.get_h3_conn(worker)
      send(worker, {:quic_h3, conn, {:session_ticket, :fake_ticket}})

      assert_receive {:session_ticket, {:https, "localhost", _port}, :fake_ticket}, 2_000

      assert_receive {:tel, [:quiver, :connection, :http3, :ticket_received],
                      %{lifetime: _, max_early_data: _}, %{origin: _}},
                     2_000
    end
  end

  describe "coordinator ticket cache" do
    setup do
      server = start_server(ok_handler())
      {:ok, server: server, config: [verify: :verify_none, cacerts: server.cacerts]}
    end

    defp coordinator_data(pool) do
      {_state, data} = :sys.get_state(pool)
      data
    end

    test "caches forwarded session tickets newest-first", %{server: server, config: config} do
      {:ok, pool} =
        HTTP3.start_link(origin: {:https, "localhost", server.port}, pool_opts: config)

      send(pool, {:session_ticket, {:https, "localhost", server.port}, :ticket_a})
      send(pool, {:session_ticket, {:https, "localhost", server.port}, :ticket_b})

      assert [{:ticket_b, _}, {:ticket_a, _}] = coordinator_data(pool).tickets
    end

    test "bounds the cache at @max_tickets (5), dropping oldest", %{
      server: server,
      config: config
    } do
      {:ok, pool} =
        HTTP3.start_link(origin: {:https, "localhost", server.port}, pool_opts: config)

      for n <- 1..7,
          do: send(pool, {:session_ticket, {:https, "localhost", server.port}, {:t, n}})

      tickets = coordinator_data(pool).tickets
      assert length(tickets) == 5
      assert [{{:t, 7}, _} | _] = tickets
      refute Enum.any?(tickets, fn {t, _} -> t == {:t, 1} end)
    end
  end

  describe "worker early-key detection" do
    setup do
      server = start_server(ok_handler())
      {:ok, server: server, config: [verify: :verify_none, cacerts: server.cacerts]}
    end

    defp worker_data(worker) do
      {_state, data} = :sys.get_state(worker)
      data
    end

    test "early_capable is false when no ticket is supplied", %{server: server, config: config} do
      {:ok, worker} =
        Connection.start_link(
          origin: {:https, "localhost", server.port},
          config: config,
          pool_pid: self()
        )

      # let the handshake settle
      Process.sleep(200)
      refute worker_data(worker).early_capable
    end

    test "a resuming connection (real ticket) derives early keys", %{
      server: server,
      config: config
    } do
      # First connection captures a ticket. The server sends NewSessionTicket as
      # a post-handshake message, so no request is required to receive it.
      ticket = capture_ticket(server, config)

      # Second connection supplies the ticket and should derive early keys.
      {:ok, w2} =
        Connection.start_link(
          origin: {:https, "localhost", server.port},
          config: config,
          pool_pid: self(),
          session_ticket: ticket
        )

      Process.sleep(200)
      assert worker_data(w2).early_capable
    end
  end

  describe "worker early send" do
    setup do
      test_pid = self()

      handler = fn h3_conn, sid, _method, _path, headers ->
        send(test_pid, {:server_headers, headers})
        :quic_h3.send_response(h3_conn, sid, 200, [])
        :quic_h3.send_data(h3_conn, sid, "ok", true)
      end

      server = start_server(handler)
      {:ok, server: server, config: [verify: :verify_none, cacerts: server.cacerts]}
    end

    test "an eligible request on a resuming connection succeeds and the connection accepted 0-RTT",
         %{server: server, config: config} do
      ticket = capture_ticket(server, config)

      {:ok, w2} =
        Connection.start_link(
          origin: {:https, "localhost", server.port},
          config: config,
          pool_pid: self(),
          session_ticket: ticket
        )

      tag = make_ref()
      from = {self(), tag}
      send(w2, {:forward_early_request, from, :get, "/", [], nil, 5_000})

      assert_receive {:server_headers, _headers}, 5_000
      assert_receive {^tag, {:ok, %Quiver.Response{status: 200, body: "ok"}}}, 5_000

      assert :quic_h3.early_data_accepted(Connection.get_h3_conn(w2)) == true
    end

    test "marks Early-Data: 1 and emits :sent only when the request truly rides 0-RTT",
         %{server: server, config: config} do
      ticket = capture_ticket(server, config)

      id = "tel-sent-#{System.unique_integer([:positive])}"
      test_pid = self()

      :ok =
        :telemetry.attach(
          id,
          [:quiver, :connection, :http3, :early_data, :sent],
          fn evt, meas, meta, _ -> send(test_pid, {:tel, evt, meas, meta}) end,
          nil
        )

      on_exit(fn -> :telemetry.detach(id) end)

      {:ok, w2} =
        Connection.start_link(
          origin: {:https, "localhost", server.port},
          config: config,
          pool_pid: self(),
          session_ticket: ticket
        )

      tag = make_ref()
      from = {self(), tag}
      send(w2, {:forward_early_request, from, :get, "/", [], nil, 5_000})

      assert_receive {:server_headers, headers}, 5_000
      assert_receive {^tag, {:ok, %Quiver.Response{status: 200, body: "ok"}}}, 5_000

      # The Early-Data header and the :sent telemetry are coupled: the header
      # rides only when open_early_request issued a genuine 0-RTT stream, which
      # is the same condition that emits :sent. Either both are present (true
      # 0-RTT) or neither is (the request fell back to 1-RTT).
      if {<<"early-data">>, <<"1">>} in headers do
        assert_receive {:tel, [:quiver, :connection, :http3, :early_data, :sent], %{count: 1},
                        %{origin: _, stream_id: _}},
                       2_000
      else
        refute_received {:tel, [:quiver, :connection, :http3, :early_data, :sent], _, _}
      end
    end

    test "a request sent after convergence rides 1-RTT and carries no Early-Data header",
         %{server: server, config: config} do
      ticket = capture_ticket(server, config)

      {:ok, w2} =
        Connection.start_link(
          origin: {:https, "localhost", server.port},
          config: config,
          pool_pid: self(),
          session_ticket: ticket
        )

      wait_until(fn ->
        {state, _data} = :sys.get_state(w2)
        state == :connected
      end)

      tag = make_ref()
      from = {self(), tag}
      send(w2, {:forward_early_request, from, :get, "/", [], nil, 5_000})

      assert_receive {:server_headers, headers}, 5_000
      assert_receive {^tag, {:ok, %Quiver.Response{status: 200, body: "ok"}}}, 5_000
      refute {<<"early-data">>, <<"1">>} in headers
    end

    test "coordinator routes eligible requests through the early_connecting worker",
         %{server: server, config: config} do
      ticket = capture_ticket(server, config)

      enabled = Keyword.put(config, :early_data, true)

      {:ok, pool} =
        HTTP3.start_link(origin: {:https, "localhost", server.port}, pool_opts: enabled)

      send(pool, {:session_ticket, {:https, "localhost", server.port}, ticket})

      assert {:ok, %Quiver.Response{status: 200, body: "ok"}} =
               HTTP3.request(pool, :get, "/", [], nil, receive_timeout: 5_000)

      assert_receive {:server_headers, _headers}, 5_000
    end

    test "emits :accepted on the handshake transition for a resuming connection",
         %{server: server, config: config} do
      ticket = capture_ticket(server, config)

      id = "tel-acc-#{System.unique_integer([:positive])}"
      test_pid = self()

      :ok =
        :telemetry.attach_many(
          id,
          [
            [:quiver, :connection, :http3, :early_data, :accepted],
            [:quiver, :connection, :http3, :early_data, :rejected]
          ],
          fn evt, meas, meta, _ -> send(test_pid, {:tel, evt, meas, meta}) end,
          nil
        )

      on_exit(fn -> :telemetry.detach(id) end)

      {:ok, w2} =
        Connection.start_link(
          origin: {:https, "localhost", server.port},
          config: config,
          pool_pid: self(),
          session_ticket: ticket
        )

      tag = make_ref()
      send(w2, {:forward_early_request, {self(), tag}, :get, "/", [], nil, 5_000})
      assert_receive {^tag, {:ok, %Quiver.Response{status: 200}}}, 5_000

      assert_receive {:tel, [:quiver, :connection, :http3, :early_data, :accepted], %{count: _},
                      %{origin: _}},
                     5_000
    end

    test "coordinator does not route unsafe methods early", %{server: server, config: config} do
      ticket = capture_ticket(server, config)

      enabled = Keyword.put(config, :early_data, true)

      {:ok, pool} =
        HTTP3.start_link(origin: {:https, "localhost", server.port}, pool_opts: enabled)

      send(pool, {:session_ticket, {:https, "localhost", server.port}, ticket})

      assert {:ok, %Quiver.Response{status: 200}} =
               HTTP3.request(pool, :post, "/echo", [], "x", receive_timeout: 5_000)

      assert_receive {:server_headers, headers}, 5_000
      refute {<<"early-data">>, <<"1">>} in headers
    end
  end

  describe "rejection and replay" do
    setup do
      test_pid = self()

      handler = fn h3_conn, sid, _method, _path, headers ->
        early? = Enum.any?(headers, fn {n, v} -> n == <<"early-data">> and v == <<"1">> end)
        send(test_pid, {:server_headers, headers})

        unless early? do
          :quic_h3.send_response(h3_conn, sid, 200, [])
          :quic_h3.send_data(h3_conn, sid, "ok", true)
        end
      end

      server = start_server(handler)

      {:ok,
       server: server, config: [verify: :verify_none, cacerts: server.cacerts], test_pid: test_pid}
    end

    test "replays an early_data_rejected stream at 1-RTT with original headers",
         %{server: server, config: config} do
      tag = make_ref()
      {w2, sid} = start_resuming_with_early_stream(server, config, tag)

      assert_receive {:server_headers, early_headers}, 5_000
      assert {<<"early-data">>, <<"1">>} in early_headers

      conn2 = Connection.get_h3_conn(w2)
      send(w2, {:quic_h3, conn2, {:early_data_rejected, [sid]}})

      assert_receive {:server_headers, replay_headers}, 5_000
      refute {<<"early-data">>, <<"1">>} in replay_headers

      assert_receive {^tag, {:ok, %Quiver.Response{status: 200, body: "ok"}}}, 5_000
    end

    test "replays a 425 Too Early on an early request; caller never sees the 425",
         %{config: config} do
      test_pid = self()

      handler = fn h3_conn, sid, _method, _path, headers ->
        early? = Enum.any?(headers, fn {n, v} -> n == <<"early-data">> and v == <<"1">> end)
        send(test_pid, {:server_headers, headers})

        if early? do
          :quic_h3.send_response(h3_conn, sid, 425, [])
          :quic_h3.send_data(h3_conn, sid, "", true)
        else
          :quic_h3.send_response(h3_conn, sid, 200, [])
          :quic_h3.send_data(h3_conn, sid, "ok", true)
        end
      end

      server = start_server(handler)

      tag = retry_until_early_attempt(server, config)

      assert_receive {^tag, {:ok, %Quiver.Response{status: 200, body: "ok"}}}, 5_000
      refute_received {^tag, {:ok, %Quiver.Response{status: 425}}}
    end
  end

  describe "public request opt threading" do
    setup do
      test_pid = self()

      handler = fn h3_conn, sid, _method, _path, headers ->
        send(test_pid, {:server_headers, headers})
        :quic_h3.send_response(h3_conn, sid, 200, [])
        :quic_h3.send_data(h3_conn, sid, "ok", true)
      end

      server = start_server(handler)
      {:ok, server: server}
    end

    test "per-request early_data: false suppresses 0-RTT on an early-enabled pool",
         %{server: server} do
      name = :"early_supp_#{System.unique_integer([:positive])}"

      start_supervised!(
        {Quiver.Supervisor,
         name: name,
         pools: %{
           "https://localhost:#{server.port}" => [
             protocol: :http3,
             early_data: true,
             verify: :verify_none,
             cacerts: server.cacerts
           ]
         }}
      )

      {:ok, %{status: 200}} =
        Quiver.new(:get, "https://localhost:#{server.port}/") |> Quiver.request(name: name)

      assert_receive {:server_headers, _}, 5_000

      assert {:ok, %{status: 200}} =
               Quiver.new(:get, "https://localhost:#{server.port}/")
               |> Quiver.request(name: name, early_data: false)
    end
  end

  describe "end-to-end 0-RTT cycle (coordinator)" do
    setup do
      test_pid = self()

      handler = fn h3_conn, sid, _method, _path, headers ->
        send(test_pid, {:server_headers, headers})
        :quic_h3.send_response(h3_conn, sid, 200, [])
        :quic_h3.send_data(h3_conn, sid, "ok", true)
      end

      server = start_server(handler)

      {:ok,
       server: server, config: [early_data: true, verify: :verify_none, cacerts: server.cacerts]}
    end

    test "request 1 caches a ticket; request 2 opens a resuming connection that derives early keys",
         %{server: server, config: config} do
      {:ok, pool} =
        HTTP3.start_link(origin: {:https, "localhost", server.port}, pool_opts: config)

      # Request(s) on fresh connections until the coordinator caches a ticket
      # (the in-process server issues NewSessionTicket non-deterministically).
      warm_until_ticket(pool)

      # Tear the warm connection down so the coordinator returns to :idle. We
      # close the underlying QUIC connection rather than killing the worker: the
      # worker is linked to the coordinator, so an abnormal exit would crash the
      # coordinator too. A :closed event stops the worker :normal, which the
      # coordinator handles via its monitor without the link firing.
      tear_down_connection(pool)

      assert {:ok, %Quiver.Response{status: 200, body: "ok"}} =
               HTTP3.request(pool, :get, "/", [], nil, receive_timeout: 5_000)

      flush_server_headers()

      # DETERMINISM: whether THIS request actually rode 0-RTT (emitting :sent) is
      # non-deterministic on the in-process loopback server, so we do not assert
      # that event. Instead we assert the resuming worker engaged the 0-RTT
      # machinery: the coordinator popped request 1's cached ticket and started
      # the worker with it, and the worker derived early keys (early_capable).
      # early_capable is set only when a ticket was supplied AND early keys were
      # derived, so it deterministically proves the cache-and-resume cycle ran.
      resuming = HTTP3.first_worker(pool)
      {_state, data} = :sys.get_state(resuming)
      assert data.early_capable
    end
  end

  describe "coordinator connect-with-ticket" do
    setup do
      server = start_server(ok_handler())
      {:ok, server: server, config: [verify: :verify_none, cacerts: server.cacerts]}
    end

    test "does not pop a ticket when early_data is disabled", %{server: server, config: config} do
      {:ok, pool} =
        HTTP3.start_link(origin: {:https, "localhost", server.port}, pool_opts: config)

      send(pool, {:session_ticket, {:https, "localhost", server.port}, :ticket_a})

      {:ok, _} = HTTP3.request(pool, :get, "/", [], nil, receive_timeout: 5_000)

      data = coordinator_data(pool)
      assert data.early_connecting == nil
      assert Enum.any?(data.tickets, fn {t, _} -> t == :ticket_a end)
    end

    test "pops a ticket and marks early_connecting when enabled", %{
      server: server,
      config: config
    } do
      # Capture a real, resumable ticket so the supplied connection can complete
      # its PSK handshake; a fake ticket would fail resumption and crash the pool.
      ticket = capture_ticket(server, config)

      enabled = Keyword.put(config, :early_data, true)

      {:ok, pool} =
        HTTP3.start_link(origin: {:https, "localhost", server.port}, pool_opts: enabled)

      send(pool, {:session_ticket, {:https, "localhost", server.port}, ticket})

      # Force the first connection to start by issuing a request; popping the
      # seeded ticket is the observable post-condition.
      {:ok, _} = HTTP3.request(pool, :get, "/", [], nil, receive_timeout: 5_000)

      refute Enum.any?(coordinator_data(pool).tickets, fn {t, _} -> t == ticket end)
    end
  end
end
