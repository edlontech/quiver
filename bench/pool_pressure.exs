alias Quiver.BenchServer
alias Quiver.Pool.HTTP1
alias Quiver.Pool.HTTP2
alias Quiver.Pool.Manager

handler = fn conn ->
  Process.sleep(10)
  Plug.Conn.send_resp(conn, 200, "ok")
end

{:ok, h1_server} = BenchServer.start_http1(handler)
{:ok, h2_server} = BenchServer.start_http2(handler)

{:ok, _} =
  Quiver.Supervisor.start_link(
    name: :bench_pressure_h1,
    pools: %{default: [protocol: :http1, size: 2, checkout_timeout: 30_000]}
  )

{:ok, _} =
  Quiver.Supervisor.start_link(
    name: :bench_pressure_h2_1conn,
    pools: %{
      default: [
        protocol: :http2,
        max_connections: 1,
        checkout_timeout: 30_000,
        transport_opts: [verify: :verify_none, cacerts: h2_server.cacerts]
      ]
    }
  )

{:ok, _} =
  Quiver.Supervisor.start_link(
    name: :bench_pressure_h2_5conn,
    pools: %{
      default: [
        protocol: :http2,
        max_connections: 5,
        checkout_timeout: 30_000,
        transport_opts: [verify: :verify_none, cacerts: h2_server.cacerts]
      ]
    }
  )

origin_h1 = {:http, "127.0.0.1", h1_server.port}
origin_h2 = {:https, "127.0.0.1", h2_server.port}

{:ok, h1_pool} = Manager.get_pool(:bench_pressure_h1, origin_h1)
{:ok, h2_1conn_pool} = Manager.get_pool(:bench_pressure_h2_1conn, origin_h2)
{:ok, h2_5conn_pool} = Manager.get_pool(:bench_pressure_h2_5conn, origin_h2)

File.mkdir_p!("bench/output")

Benchee.run(
  %{
    "http1 (size: 2)" => fn -> HTTP1.request(h1_pool, :get, "/", [], nil) end,
    "http2 (max_connections: 1)" => fn -> HTTP2.request(h2_1conn_pool, :get, "/", [], nil) end,
    "http2 (max_connections: 5)" => fn -> HTTP2.request(h2_5conn_pool, :get, "/", [], nil) end
  },
  warmup: 2,
  time: 15,
  parallel: 20,
  formatters: [
    Benchee.Formatters.Console,
    {Benchee.Formatters.HTML, file: "bench/output/pool_pressure.html"},
    {Benchee.Formatters.JSON, file: "bench/output/pool_pressure.json"}
  ]
)

BenchServer.stop(h1_server)
BenchServer.stop(h2_server)
