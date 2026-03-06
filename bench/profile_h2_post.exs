Logger.configure(level: :warning)

{:ok, server} =
  Quiver.BenchServer.start_http2(fn conn ->
    {:ok, body, conn} = Plug.Conn.read_body(conn)

    conn
    |> Plug.Conn.put_resp_content_type("text/plain")
    |> Plug.Conn.send_resp(200, "#{byte_size(body)}")
  end)

{:ok, _sup} =
  Supervisor.start_link(
    [
      {Quiver.Supervisor,
       name: :profiler,
       pools: %{
         :default => [
           protocol: :http2,
           max_connections: 1,
           cacerts: server.cacerts,
           verify: :verify_none
         ]
       }}
    ],
    strategy: :one_for_one
  )

port = server.port
body_1mb = :crypto.strong_rand_bytes(1_048_576)
url = "https://127.0.0.1:#{port}/echo"

req =
  Quiver.new(:post, url)
  |> Quiver.header("content-type", "application/octet-stream")
  |> Quiver.body(body_1mb)

# Warm up - establish connection
{:ok, _} = Quiver.request(req, name: :profiler)
IO.puts("Warmup done")

# --- eprof: where is wall-clock time spent? ---
IO.puts("\n=== eprof: single 1MB POST (all processes) ===\n")

:eprof.start()
:eprof.start_profiling(Process.list())

{:ok, resp} = Quiver.request(req, name: :profiler)

:eprof.stop_profiling()
:eprof.analyze(:total)
:eprof.stop()

IO.puts("\nResponse: #{resp.status} body=#{resp.body}")

# --- eprof: concurrent 1MB POSTs ---
IO.puts("\n=== eprof: 10 concurrent 1MB POSTs ===\n")

:eprof.start()
:eprof.start_profiling(Process.list())

tasks =
  for _ <- 1..10 do
    Task.async(fn -> Quiver.request(req, name: :profiler) end)
  end

results = Task.await_many(tasks, 30_000)
:eprof.stop_profiling()
:eprof.analyze(:total)
:eprof.stop()

IO.puts(
  "\nAll #{length(results)} requests completed: #{Enum.all?(results, &match?({:ok, _}, &1))}"
)

# Cleanup
Quiver.BenchServer.stop(server)
