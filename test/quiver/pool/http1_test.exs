defmodule Quiver.Pool.HTTP1Test do
  use Quiver.TestCase.Integration, async: true
  @moduletag :integration

  alias Quiver.Pool.HTTP1, as: Pool
  alias Quiver.TestServer

  describe "start_link/1" do
    test "starts a pool with valid config" do
      {:ok, %{port: port} = server} = start_server()

      assert {:ok, pool} =
               Pool.start_link(
                 origin: {:http, "127.0.0.1", port},
                 pool_opts: []
               )

      assert is_pid(pool)
      GenServer.stop(pool)
      TestServer.stop(server)
    end

    test "starts a pool with a via-tuple name" do
      name = :"test_registry_#{System.unique_integer([:positive])}"
      {:ok, _} = Registry.start_link(keys: :unique, name: name)
      {:ok, %{port: port} = server} = start_server()
      origin = {:http, "127.0.0.1", port}

      assert {:ok, pool} =
               Pool.start_link(
                 origin: origin,
                 pool_opts: [],
                 name: {:via, Registry, {name, origin}}
               )

      assert [{^pool, _}] = Registry.lookup(name, origin)

      GenServer.stop(pool)
      TestServer.stop(server)
    end
  end

  describe "request/6" do
    test "sends GET through pool and receives response" do
      {:ok, %{port: port} = server} = start_server()
      {:ok, pool} = start_pool(port)

      assert {:ok, %Quiver.Response{status: 200, body: "ok"}} =
               Pool.request(pool, :get, "/", [], nil)

      GenServer.stop(pool)
      TestServer.stop(server)
    end

    test "sends POST with body through pool" do
      handler = fn conn -> Plug.Conn.send_resp(conn, 201, "created") end

      {:ok, %{port: port} = server} = TestServer.start(handler)
      {:ok, pool} = start_pool(port)

      assert {:ok, %Quiver.Response{status: 201, body: "created"}} =
               Pool.request(
                 pool,
                 :post,
                 "/items",
                 [{"content-type", "application/json"}],
                 ~s({"a":1})
               )

      GenServer.stop(pool)
      TestServer.stop(server)
    end

    test "reuses idle connection for second request" do
      {:ok, %{port: port} = server} = start_server()
      {:ok, pool} = start_pool(port)

      assert {:ok, %Quiver.Response{status: 200}} =
               Pool.request(pool, :get, "/first", [], nil)

      poll_until(fn -> Pool.stats(pool).idle >= 1 end)

      assert {:ok, %Quiver.Response{status: 200}} =
               Pool.request(pool, :get, "/second", [], nil)

      GenServer.stop(pool)
      TestServer.stop(server)
    end

    test "creates multiple connections under concurrency" do
      {:ok, %{port: port} = server} = start_slow_server(50)
      {:ok, pool} = start_pool(port, size: 5)

      tasks =
        for _ <- 1..5 do
          Task.async(fn -> Pool.request(pool, :get, "/", [], nil) end)
        end

      results = Task.await_many(tasks, 10_000)
      assert Enum.all?(results, &match?({:ok, %Quiver.Response{status: 200}}, &1))

      GenServer.stop(pool)
      TestServer.stop(server)
    end

    test "returns CheckoutTimeout when pool is exhausted" do
      {:ok, %{port: port} = server} = start_slow_server(500)
      {:ok, pool} = start_pool(port, size: 1, checkout_timeout: 100)

      task = Task.async(fn -> Pool.request(pool, :get, "/slow", [], nil) end)
      poll_until(fn -> Pool.stats(pool).active == 1 end)

      assert {:error, %Quiver.Error.CheckoutTimeout{}} =
               Pool.request(pool, :get, "/", [], nil)

      Task.await(task, 5_000)
      GenServer.stop(pool)
      TestServer.stop(server)
    end
  end

  describe "dead connection eviction" do
    test "evicts connection closed by server on checkin" do
      handler = fn conn ->
        conn
        |> Plug.Conn.put_resp_header("connection", "close")
        |> Plug.Conn.send_resp(200, "ok")
      end

      {:ok, %{port: port} = server} = TestServer.start(handler)
      {:ok, pool} = start_pool(port)

      assert {:ok, %Quiver.Response{status: 200}} =
               Pool.request(pool, :get, "/", [], nil)

      poll_until(fn -> Pool.stats(pool).active == 0 end)
      assert Pool.stats(pool).idle == 0

      GenServer.stop(pool)
      TestServer.stop(server)
    end
  end

  describe "idle timeout" do
    test "evicts connection idle beyond idle_timeout" do
      {:ok, %{port: port} = server} = start_server()
      {:ok, pool} = start_pool(port, size: 1, idle_timeout: 200, ping_interval: 100)

      assert {:ok, _} = Pool.request(pool, :get, "/", [], nil)
      poll_until(fn -> Pool.stats(pool).idle == 1 end)
      poll_until(fn -> Pool.stats(pool).idle == 0 end, 2_000)

      GenServer.stop(pool)
      TestServer.stop(server)
    end
  end

  describe "stats/1" do
    test "reports zero counts for fresh pool" do
      {:ok, %{port: port} = server} = start_server()
      {:ok, pool} = start_pool(port)

      assert %{idle: 0, active: 0, queued: 0} = Pool.stats(pool)

      GenServer.stop(pool)
      TestServer.stop(server)
    end

    test "tracks idle after request completes" do
      {:ok, %{port: port} = server} = start_server()
      {:ok, pool} = start_pool(port)

      assert {:ok, _} = Pool.request(pool, :get, "/", [], nil)
      poll_until(fn -> Pool.stats(pool).idle == 1 end)
      assert Pool.stats(pool).active == 0

      GenServer.stop(pool)
      TestServer.stop(server)
    end
  end

  describe "concurrent stress" do
    test "10 sequential requests through pool of 3" do
      {:ok, %{port: port} = server} = start_server()
      {:ok, pool} = start_pool(port, size: 3)

      results =
        for i <- 1..10 do
          Pool.request(pool, :get, "/req-#{i}", [], nil)
        end

      assert Enum.all?(results, &match?({:ok, %Quiver.Response{status: 200}}, &1))

      poll_until(fn -> Pool.stats(pool).active == 0 end)
      assert Pool.stats(pool).idle <= 3

      GenServer.stop(pool)
      TestServer.stop(server)
    end
  end

  describe "connection failure" do
    test "returns transport error when server is unreachable" do
      {:ok, pool} = start_pool(1, size: 1, checkout_timeout: 2_000)

      assert {:error, error} = Pool.request(pool, :get, "/", [], nil)
      refute match?(%Quiver.Error.CheckoutTimeout{}, error)

      GenServer.stop(pool)
    end
  end

  describe "request/6 with streaming body" do
    test "sends streaming body through HTTP/1 pool" do
      handler = fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        Plug.Conn.send_resp(conn, 200, body)
      end

      {:ok, %{port: port} = server} = TestServer.start(handler)
      {:ok, pool} = start_pool(port)

      chunks = Stream.map(1..5, fn i -> "chunk#{i}" end)

      assert {:ok, %Quiver.Response{status: 200, body: body}} =
               Pool.request(
                 pool,
                 :post,
                 "/",
                 [{"transfer-encoding", "chunked"}],
                 {:stream, chunks}
               )

      assert body == "chunk1chunk2chunk3chunk4chunk5"

      GenServer.stop(pool)
      TestServer.stop(server)
    end

    test "reuses connection after streaming body request" do
      handler = fn conn ->
        case conn.method do
          "POST" ->
            {:ok, body, conn} = Plug.Conn.read_body(conn)
            Plug.Conn.send_resp(conn, 200, body)

          _ ->
            Plug.Conn.send_resp(conn, 200, "ok")
        end
      end

      {:ok, %{port: port} = server} = TestServer.start(handler)
      {:ok, pool} = start_pool(port)

      chunks = Stream.map(1..3, fn i -> "part#{i}" end)

      assert {:ok, %Quiver.Response{status: 200}} =
               Pool.request(
                 pool,
                 :post,
                 "/",
                 [{"transfer-encoding", "chunked"}],
                 {:stream, chunks}
               )

      poll_until(fn -> Pool.stats(pool).idle >= 1 end)

      assert {:ok, %Quiver.Response{status: 200, body: "ok"}} =
               Pool.request(pool, :get, "/second", [], nil)

      GenServer.stop(pool)
      TestServer.stop(server)
    end
  end

  describe "stream_request/6" do
    test "returns StreamResponse with status, headers, and lazy body" do
      {:ok, %{port: port} = server} = start_server()
      {:ok, pool} = start_pool(port)

      assert {:ok, %Quiver.StreamResponse{status: 200, headers: headers, body: body}} =
               Pool.stream_request(pool, :get, "/", [], nil)

      assert is_list(headers)
      assert body |> Enum.to_list() |> IO.iodata_to_binary() == "ok"

      GenServer.stop(pool)
      TestServer.stop(server)
    end

    test "body stream handles early halt via Enum.take" do
      handler = fn conn -> Plug.Conn.send_resp(conn, 200, String.duplicate("x", 1000)) end

      {:ok, %{port: port} = server} = TestServer.start(handler)
      {:ok, pool} = start_pool(port)

      assert {:ok, %Quiver.StreamResponse{body: body}} =
               Pool.stream_request(pool, :get, "/", [], nil)

      chunks = Enum.take(body, 1)
      assert chunks != []

      GenServer.stop(pool)
      TestServer.stop(server)
    end
  end

  # -- Helpers --

  defp start_server do
    TestServer.start(fn conn -> Plug.Conn.send_resp(conn, 200, "ok") end)
  end

  defp start_slow_server(delay_ms) do
    TestServer.start(fn conn ->
      Process.sleep(delay_ms)
      Plug.Conn.send_resp(conn, 200, "ok")
    end)
  end

  defp start_pool(port, opts \\ []) do
    Pool.start_link(origin: {:http, "127.0.0.1", port}, pool_opts: opts)
  end
end
