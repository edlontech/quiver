alias Quiver.BenchServer
alias Quiver.Pool.HTTP1
alias Quiver.Pool.HTTP2
alias Quiver.Pool.Manager

sizes = %{"/1kb" => 1_024, "/100kb" => 102_400, "/1mb" => 1_048_576}

handler = fn conn ->
  size = Map.get(sizes, conn.request_path, 100)
  Plug.Conn.send_resp(conn, 200, :binary.copy("x", size))
end

{:ok, h1_server} = BenchServer.start_http1(handler)
{:ok, h2_server} = BenchServer.start_http2(handler)

{:ok, _} =
  Quiver.Supervisor.start_link(
    name: :bench_stream_h1,
    pools: %{default: [protocol: :http1, size: 30]}
  )

{:ok, _} =
  Quiver.Supervisor.start_link(
    name: :bench_stream_h2,
    pools: %{
      default: [
        protocol: :http2,
        max_connections: 3,
        verify: :verify_none,
        cacerts: h2_server.cacerts
      ]
    }
  )

{:ok, h1_pool} = Manager.get_pool(:bench_stream_h1, {:http, "127.0.0.1", h1_server.port})
{:ok, h2_pool} = Manager.get_pool(:bench_stream_h2, {:https, "127.0.0.1", h2_server.port})

HTTP1.request(h1_pool, :get, "/1kb", [], nil)
HTTP2.request(h2_pool, :get, "/1kb", [], nil)

File.mkdir_p!("bench/output")
File.mkdir_p!("guides/benchmarks")

# -- Stream vs collected across payload sizes --

for {path, label} <- [{"/1kb", "1kb"}, {"/100kb", "100kb"}, {"/1mb", "1mb"}] do
  IO.puts("\n--- streaming vs collected #{label} (parallel: 10) ---\n")

  Benchee.run(
    %{
      "http1 collected" => fn ->
        {:ok, _resp} = HTTP1.request(h1_pool, :get, path, [], nil)
      end,
      "http1 stream" => fn ->
        {:ok, resp} = HTTP1.stream_request(h1_pool, :get, path, [], nil)
        Enum.to_list(resp.body)
      end,
      "http2 collected" => fn ->
        {:ok, _resp} = HTTP2.request(h2_pool, :get, path, [], nil)
      end,
      "http2 stream" => fn ->
        {:ok, resp} = HTTP2.stream_request(h2_pool, :get, path, [], nil)
        Enum.to_list(resp.body)
      end
    },
    warmup: 2,
    time: 10,
    memory_time: 2,
    reduction_time: 2,
    parallel: 10,
    formatters: [
      {Benchee.Formatters.Console, extended_statistics: true},
      {Benchee.Formatters.Markdown, file: "guides/benchmarks/streaming_#{label}.md"},
      {Benchee.Formatters.JSON, file: "bench/output/streaming_#{label}.json"}
    ]
  )
end

# -- Early halt: take first chunk vs full collect (1mb payload) --

IO.puts("\n--- early halt (Enum.take 1) vs full collect on 1mb (parallel: 10) ---\n")

Benchee.run(
  %{
    "http1 collect 1mb" => fn ->
      {:ok, _resp} = HTTP1.request(h1_pool, :get, "/1mb", [], nil)
    end,
    "http1 stream take 1" => fn ->
      {:ok, resp} = HTTP1.stream_request(h1_pool, :get, "/1mb", [], nil)
      Enum.take(resp.body, 1)
    end,
    "http2 collect 1mb" => fn ->
      {:ok, _resp} = HTTP2.request(h2_pool, :get, "/1mb", [], nil)
    end,
    "http2 stream take 1" => fn ->
      {:ok, resp} = HTTP2.stream_request(h2_pool, :get, "/1mb", [], nil)
      Enum.take(resp.body, 1)
    end
  },
  warmup: 2,
  time: 10,
  memory_time: 2,
  reduction_time: 2,
  parallel: 10,
  formatters: [
    {Benchee.Formatters.Console, extended_statistics: true},
    {Benchee.Formatters.Markdown, file: "guides/benchmarks/streaming_early_halt.md"},
    {Benchee.Formatters.JSON, file: "bench/output/streaming_early_halt.json"}
  ]
)

BenchServer.stop(h1_server)
BenchServer.stop(h2_server)
