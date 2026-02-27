alias Quiver.BenchServer
alias Quiver.Pool.HTTP2
alias Quiver.Pool.Manager

sizes = %{"/1kb" => 1_024, "/100kb" => 102_400, "/1mb" => 1_048_576}

handler = fn conn ->
  size = Map.get(sizes, conn.request_path, 100)
  Plug.Conn.send_resp(conn, 200, :binary.copy("x", size))
end

{:ok, h2_server} = BenchServer.start_http2(handler)

{:ok, _} =
  Quiver.Supervisor.start_link(
    name: :bench_profile,
    pools: %{
      default: [
        protocol: :http2,
        max_connections: 1,
        transport_opts: [verify: :verify_none, cacerts: h2_server.cacerts]
      ]
    }
  )

{:ok, h2_pool} = Manager.get_pool(:bench_profile, {:https, "127.0.0.1", h2_server.port})

# Warm up the connection
{:ok, _} = HTTP2.request(h2_pool, :get, "/1kb", [], nil)

profile_request = fn path, label ->
  IO.puts("\n#{String.duplicate("=", 72)}")
  IO.puts("PROFILING: #{label}")
  IO.puts(String.duplicate("=", 72))

  :eprof.start()
  :eprof.start_profiling(:erlang.processes())

  results =
    1..5
    |> Enum.map(fn _ ->
      Task.async(fn -> HTTP2.request(h2_pool, :get, path, [], nil) end)
    end)
    |> Task.await_many(30_000)

  :eprof.stop_profiling()
  :eprof.analyze(:total)
  :eprof.stop()

  Enum.each(results, fn
    {:ok, resp} -> IO.puts("  response body size: #{byte_size(resp.body)} bytes")
    {:error, err} -> IO.puts("  error: #{inspect(err)}")
  end)
end

profile_request.("/1kb", "1 KB response (baseline)")
profile_request.("/100kb", "100 KB response")
profile_request.("/1mb", "1 MB response")

BenchServer.stop(h2_server)
