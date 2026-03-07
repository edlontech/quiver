defmodule Quiver.Pool.HTTP2.ConnectionTest do
  use Quiver.TestCase.Integration, async: true
  @moduletag :integration
  use AssertEventually, timeout: 2_000, interval: 50

  alias Quiver.Pool.HTTP2.Connection
  alias Quiver.TestServer

  defp start_server(handler \\ fn conn -> Plug.Conn.send_resp(conn, 200, "ok") end) do
    TestServer.start(handler, https: true, http_2_only: true)
  end

  describe "start_link/1" do
    test "connects and reaches :connected state" do
      {:ok, %{port: port, cacerts: cacerts}} = start_server()

      {:ok, pid} =
        Connection.start_link(
          origin: {:https, "127.0.0.1", port},
          config: [verify: :verify_none, cacerts: cacerts]
        )

      assert Connection.open?(pid)
      assert Connection.available_streams(pid) > 0
    end

    test "reports closed after close/1" do
      {:ok, %{port: port, cacerts: cacerts}} = start_server()

      {:ok, pid} =
        Connection.start_link(
          origin: {:https, "127.0.0.1", port},
          config: [verify: :verify_none, cacerts: cacerts]
        )

      assert :ok = Connection.close(pid)
      refute Process.alive?(pid)
    end
  end

  describe "request/6" do
    test "sends GET and receives response" do
      {:ok, %{port: port, cacerts: cacerts}} =
        start_server(fn conn -> Plug.Conn.send_resp(conn, 200, "hello") end)

      {:ok, pid} =
        Connection.start_link(
          origin: {:https, "127.0.0.1", port},
          config: [verify: :verify_none, cacerts: cacerts]
        )

      assert {:ok, response} = Connection.request(pid, :get, "/", [], nil, receive_timeout: 5_000)
      assert response.status == 200
      assert response.body == "hello"
    end

    test "sends POST with body and receives response" do
      {:ok, %{port: port, cacerts: cacerts}} =
        start_server(fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          Plug.Conn.send_resp(conn, 201, body)
        end)

      {:ok, pid} =
        Connection.start_link(
          origin: {:https, "127.0.0.1", port},
          config: [verify: :verify_none, cacerts: cacerts]
        )

      assert {:ok, response} =
               Connection.request(pid, :post, "/", [{"content-type", "text/plain"}], "payload",
                 receive_timeout: 5_000
               )

      assert response.status == 201
      assert response.body == "payload"
    end

    test "handles concurrent requests on single connection" do
      {:ok, %{port: port, cacerts: cacerts}} =
        start_server(fn conn ->
          Process.sleep(50)
          Plug.Conn.send_resp(conn, 200, conn.request_path)
        end)

      {:ok, pid} =
        Connection.start_link(
          origin: {:https, "127.0.0.1", port},
          config: [verify: :verify_none, cacerts: cacerts]
        )

      tasks =
        for i <- 1..5 do
          Task.async(fn ->
            Connection.request(pid, :get, "/path/#{i}", [], nil, receive_timeout: 5_000)
          end)
        end

      results = Task.await_many(tasks, 10_000)

      assert Enum.all?(results, &match?({:ok, %{status: 200}}, &1))
      bodies = Enum.map(results, fn {:ok, r} -> r.body end) |> Enum.sort()
      assert bodies == Enum.map(1..5, &"/path/#{&1}") |> Enum.sort()
    end
  end

  describe "GOAWAY handling" do
    test "rejects new requests after server closes connection" do
      {:ok, %{port: port, cacerts: cacerts, server: server, agent: agent}} = start_server()

      {:ok, pid} =
        Connection.start_link(
          origin: {:https, "127.0.0.1", port},
          config: [verify: :verify_none, cacerts: cacerts]
        )

      assert Connection.open?(pid)

      TestServer.stop(%{server: server, agent: agent})

      assert_eventually(not Connection.open?(pid))
    end
  end

  describe "caller crash" do
    test "cleans up stream when caller dies" do
      {:ok, %{port: port, cacerts: cacerts}} =
        start_server(fn conn ->
          Process.sleep(5_000)
          Plug.Conn.send_resp(conn, 200, "slow")
        end)

      {:ok, pid} =
        Connection.start_link(
          origin: {:https, "127.0.0.1", port},
          config: [verify: :verify_none, cacerts: cacerts]
        )

      task =
        Task.async(fn ->
          Connection.request(pid, :get, "/slow", [], nil, receive_timeout: 60_000)
        end)

      assert_eventually(Connection.available_streams(pid) < Connection.max_streams(pid))

      Task.shutdown(task, :brutal_kill)

      assert_eventually(Connection.available_streams(pid) == Connection.max_streams(pid))
    end
  end

  describe "request timeout" do
    test "returns error on receive_timeout" do
      {:ok, %{port: port, cacerts: cacerts}} =
        start_server(fn conn ->
          Process.sleep(5_000)
          Plug.Conn.send_resp(conn, 200, "slow")
        end)

      {:ok, pid} =
        Connection.start_link(
          origin: {:https, "127.0.0.1", port},
          config: [verify: :verify_none, cacerts: cacerts]
        )

      assert {:error, :recv_timeout} =
               Connection.request(pid, :get, "/slow", [], nil, receive_timeout: 200)
    end
  end

  describe "streaming requests" do
    test "forward_stream replies with status, headers, ref, and worker pid" do
      {:ok, %{port: port, cacerts: cacerts}} =
        start_server(fn conn -> Plug.Conn.send_resp(conn, 200, "streaming hello") end)

      {:ok, worker} =
        Connection.start_link(
          origin: {:https, "127.0.0.1", port},
          config: [verify: :verify_none, cacerts: cacerts]
        )

      tag = make_ref()
      from = {self(), tag}
      send(worker, {:forward_stream, from, :get, "/", [], nil, 5_000})

      assert_receive {^tag, {:ok, status, headers, ref, ^worker}}, 5_000
      assert status == 200
      assert is_list(headers)
      assert is_reference(ref)
    end

    test "demand protocol delivers body chunks and done" do
      {:ok, %{port: port, cacerts: cacerts}} =
        start_server(fn conn -> Plug.Conn.send_resp(conn, 200, "body data") end)

      {:ok, worker} =
        Connection.start_link(
          origin: {:https, "127.0.0.1", port},
          config: [verify: :verify_none, cacerts: cacerts]
        )

      tag = make_ref()
      from = {self(), tag}
      send(worker, {:forward_stream, from, :get, "/", [], nil, 5_000})

      assert_receive {^tag, {:ok, _status, _headers, ref, ^worker}}, 5_000

      body = collect_stream_chunks(worker, ref)
      assert IO.iodata_to_binary(body) == "body data"
    end

    test "cancel_stream after headers cleans up without crashing connection" do
      {:ok, %{port: port, cacerts: cacerts}} =
        start_server(fn conn -> Plug.Conn.send_resp(conn, 200, "data") end)

      {:ok, worker} =
        Connection.start_link(
          origin: {:https, "127.0.0.1", port},
          config: [verify: :verify_none, cacerts: cacerts]
        )

      tag = make_ref()
      from = {self(), tag}
      send(worker, {:forward_stream, from, :get, "/", [], nil, 5_000})

      assert_receive {^tag, {:ok, _status, _headers, ref, ^worker}}, 5_000

      send(worker, {:cancel_stream, ref, self()})

      assert_eventually(Connection.open?(worker))
    end
  end

  describe "flow-controlled POST" do
    test "large POST body completes through connection worker" do
      {:ok, %{port: port, cacerts: cacerts}} =
        start_server(fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          Plug.Conn.send_resp(conn, 200, "#{byte_size(body)}")
        end)

      {:ok, pid} =
        Connection.start_link(
          origin: {:https, "127.0.0.1", port},
          config: [verify: :verify_none, cacerts: cacerts]
        )

      large_body = :crypto.strong_rand_bytes(200_000)

      assert {:ok, response} =
               Connection.request(
                 pid,
                 :post,
                 "/",
                 [{"content-type", "application/octet-stream"}],
                 large_body,
                 receive_timeout: 30_000
               )

      assert response.status == 200
      assert response.body == "200000"
    end

    test "concurrent large POSTs complete through connection worker" do
      {:ok, %{port: port, cacerts: cacerts}} =
        start_server(fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          Plug.Conn.send_resp(conn, 200, "#{byte_size(body)}")
        end)

      {:ok, pid} =
        Connection.start_link(
          origin: {:https, "127.0.0.1", port},
          config: [verify: :verify_none, cacerts: cacerts]
        )

      tasks =
        for _ <- 1..5 do
          Task.async(fn ->
            body = :crypto.strong_rand_bytes(100_000)

            Connection.request(
              pid,
              :post,
              "/",
              [{"content-type", "application/octet-stream"}],
              body,
              receive_timeout: 30_000
            )
          end)
        end

      results = Task.await_many(tasks, 60_000)

      for result <- results do
        assert {:ok, response} = result
        assert response.status == 200
        assert response.body == "100000"
      end
    end
  end

  describe "streaming body upload" do
    test "streaming body arrives correctly at HTTP/2 server" do
      {:ok, %{port: port, cacerts: cacerts}} =
        start_server(fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          Plug.Conn.send_resp(conn, 200, body)
        end)

      {:ok, worker} =
        Connection.start_link(
          origin: {:https, "127.0.0.1", port},
          config: [verify: :verify_none, cacerts: cacerts]
        )

      chunks = ["hello", " ", "streaming", " ", "world"]
      body = {:stream, chunks}

      tag = make_ref()
      from = {self(), tag}

      send(
        worker,
        {:forward_request, from, :post, "/", [{"content-type", "text/plain"}], body, 15_000}
      )

      assert_receive {^tag, {:ok, response}}, 10_000
      assert response.status == 200
      assert response.body == "hello streaming world"
    end

    test "streaming body with large chunks" do
      {:ok, %{port: port, cacerts: cacerts}} =
        start_server(fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          Plug.Conn.send_resp(conn, 200, "#{byte_size(body)}")
        end)

      {:ok, worker} =
        Connection.start_link(
          origin: {:https, "127.0.0.1", port},
          config: [verify: :verify_none, cacerts: cacerts]
        )

      chunk = :crypto.strong_rand_bytes(50_000)
      chunks = [chunk, chunk, chunk, chunk]
      body = {:stream, chunks}

      tag = make_ref()
      from = {self(), tag}

      send(
        worker,
        {:forward_request, from, :post, "/", [{"content-type", "application/octet-stream"}], body,
         30_000}
      )

      assert_receive {^tag, {:ok, response}}, 30_000
      assert response.status == 200
      assert response.body == "200000"
    end

    test "multiple concurrent streaming requests work" do
      {:ok, %{port: port, cacerts: cacerts}} =
        start_server(fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          Plug.Conn.send_resp(conn, 201, body)
        end)

      {:ok, worker} =
        Connection.start_link(
          origin: {:https, "127.0.0.1", port},
          config: [verify: :verify_none, cacerts: cacerts]
        )

      tasks =
        for i <- 1..3 do
          Task.async(fn ->
            chunks = ["request-#{i}-part1", "-", "part2"]
            body = {:stream, chunks}
            tag = make_ref()
            from = {self(), tag}

            send(
              worker,
              {:forward_request, from, :post, "/", [{"content-type", "text/plain"}], body, 15_000}
            )

            receive do
              {^tag, result} -> result
            after
              15_000 -> {:error, :timeout}
            end
          end)
        end

      results = Task.await_many(tasks, 30_000)

      for {result, i} <- Enum.with_index(results, 1) do
        assert {:ok, response} = result
        assert response.status == 201
        assert response.body == "request-#{i}-part1-part2"
      end
    end

    test "stream task cleanup on connection close" do
      {:ok, %{port: port, cacerts: cacerts, server: server, agent: agent}} =
        start_server(fn conn ->
          Process.sleep(10_000)
          Plug.Conn.send_resp(conn, 200, "slow")
        end)

      {:ok, worker} =
        Connection.start_link(
          origin: {:https, "127.0.0.1", port},
          config: [verify: :verify_none, cacerts: cacerts]
        )

      Process.unlink(worker)
      mon = Process.monitor(worker)

      slow_stream =
        Stream.concat(
          ["first_chunk"],
          Stream.repeatedly(fn ->
            Process.sleep(500)
            "more"
          end)
        )

      body = {:stream, slow_stream}
      tag = make_ref()
      from = {self(), tag}

      send(
        worker,
        {:forward_request, from, :post, "/", [{"content-type", "text/plain"}], body, 30_000}
      )

      Process.sleep(200)

      TestServer.stop(%{server: server, agent: agent})

      assert_receive {:DOWN, ^mon, :process, ^worker, _reason}, 5_000
      refute Process.alive?(worker)
    end
  end

  defp collect_stream_chunks(worker, ref, acc \\ []) do
    send(worker, {:demand, ref, self()})

    receive do
      {:chunk, ^ref, data} -> collect_stream_chunks(worker, ref, [data | acc])
      {:done, ^ref} -> Enum.reverse(acc)
    after
      5_000 -> flunk("Timed out waiting for stream chunk")
    end
  end
end
