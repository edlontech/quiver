alias Quiver.BenchServer
alias Quiver.Pool.HTTP1
alias Quiver.Pool.HTTP2
alias Quiver.Pool.Manager

handler = fn conn -> Plug.Conn.send_resp(conn, 200, ~s({"ok":true})) end

{:ok, h1_server} = BenchServer.start_http1(handler)
{:ok, h2_server} = BenchServer.start_http2(handler)

{:ok, _} =
  Quiver.Supervisor.start_link(
    name: :bench_concurrency_h1,
    pools: %{default: [protocol: :http1, size: 60]}
  )

{:ok, _} =
  Quiver.Supervisor.start_link(
    name: :bench_concurrency_h2,
    pools: %{
      default: [
        protocol: :http2,
        max_connections: 5,
        verify: :verify_none,
        cacerts: h2_server.cacerts
      ]
    }
  )

{:ok, h1_pool} = Manager.get_pool(:bench_concurrency_h1, {:http, "127.0.0.1", h1_server.port})
{:ok, h2_pool} = Manager.get_pool(:bench_concurrency_h2, {:https, "127.0.0.1", h2_server.port})

File.mkdir_p!("bench/output")
File.mkdir_p!("guides/benchmarks")

Benchee.run(
  %{
    "http1" => fn -> HTTP1.request(h1_pool, :get, "/", [], nil) end,
    "http2" => fn -> HTTP2.request(h2_pool, :get, "/", [], nil) end
  },
  warmup: 3,
  time: 15,
  memory_time: 2,
  reduction_time: 2,
  parallel: 50,
  formatters: [
    {Benchee.Formatters.Console, extended_statistics: true},
    {Benchee.Formatters.Markdown, file: "guides/benchmarks/concurrency.md"},
    {Benchee.Formatters.JSON, file: "bench/output/concurrency.json"}
  ]
)

BenchServer.stop(h1_server)
BenchServer.stop(h2_server)
