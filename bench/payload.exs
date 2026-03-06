alias Quiver.BenchServer
alias Quiver.Pool.HTTP1
alias Quiver.Pool.HTTP2
alias Quiver.Pool.Manager

sizes = %{"/1kb" => 1_024, "/10kb" => 10_240, "/100kb" => 102_400, "/1mb" => 1_048_576}

handler = fn conn ->
  size = Map.get(sizes, conn.request_path, 100)
  Plug.Conn.send_resp(conn, 200, :binary.copy("x", size))
end

{:ok, h1_server} = BenchServer.start_http1(handler)
{:ok, h2_server} = BenchServer.start_http2(handler)

{:ok, _} =
  Quiver.Supervisor.start_link(
    name: :bench_payload_h1,
    pools: %{default: [protocol: :http1, size: 30]}
  )

{:ok, _} =
  Quiver.Supervisor.start_link(
    name: :bench_payload_h2,
    pools: %{
      default: [
        protocol: :http2,
        max_connections: 3,
        verify: :verify_none,
        cacerts: h2_server.cacerts
      ]
    }
  )

{:ok, h1_pool} = Manager.get_pool(:bench_payload_h1, {:http, "127.0.0.1", h1_server.port})
{:ok, h2_pool} = Manager.get_pool(:bench_payload_h2, {:https, "127.0.0.1", h2_server.port})

File.mkdir_p!("bench/output")

jobs =
  for {path, label} <- [{"/1kb", "1kb"}, {"/10kb", "10kb"}, {"/100kb", "100kb"}, {"/1mb", "1mb"}],
      {module, pool, proto} <- [{HTTP1, h1_pool, "http1"}, {HTTP2, h2_pool, "http2"}],
      into: %{} do
    {"#{proto} #{label}", fn -> module.request(pool, :get, path, [], nil) end}
  end

Benchee.run(
  jobs,
  warmup: 2,
  time: 10,
  memory_time: 2,
  reduction_time: 2,
  parallel: 20,
  formatters: [
    {Benchee.Formatters.Console, extended_statistics: true},
    {Benchee.Formatters.HTML,
     file: "guides/benchmarks/payload.html", auto_open: false, inline_assets: true},
    {Benchee.Formatters.JSON, file: "bench/output/payload.json"}
  ]
)

BenchServer.stop(h1_server)
BenchServer.stop(h2_server)
