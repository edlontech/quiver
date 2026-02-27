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

h2_conn_opts = [transport_opts: [verify: :verify_none, cacerts: h2_server.cacerts]]

# -- HTTP/1 pools (30 connections each) --

{:ok, _} =
  Quiver.Supervisor.start_link(
    name: :bench_vs_h1,
    pools: %{default: [protocol: :http1, size: 30]}
  )

{:ok, q_h1} = Manager.get_pool(:bench_vs_h1, {:http, "127.0.0.1", h1_server.port})

Finch.start_link(
  name: FinchH1,
  pools: %{
    "http://127.0.0.1:#{h1_server.port}" => [
      protocols: [:http1],
      count: 3,
      size: 10
    ]
  }
)

# -- HTTP/2 pools (10 connections each for fair comparison) --

{:ok, _} =
  Quiver.Supervisor.start_link(
    name: :bench_vs_h2,
    pools: %{
      default: [
        protocol: :http2,
        max_connections: 10,
        transport_opts: h2_conn_opts[:transport_opts]
      ]
    }
  )

{:ok, q_h2} = Manager.get_pool(:bench_vs_h2, {:https, "127.0.0.1", h2_server.port})

Finch.start_link(
  name: FinchH2,
  pools: %{
    "https://127.0.0.1:#{h2_server.port}" => [
      protocols: [:http2],
      count: 10,
      conn_opts: h2_conn_opts
    ]
  }
)

File.mkdir_p!("bench/output")

# Warm up all pools
HTTP1.request(q_h1, :get, "/1kb", [], nil)
HTTP2.request(q_h2, :get, "/1kb", [], nil)
Finch.build(:get, "http://127.0.0.1:#{h1_server.port}/1kb") |> Finch.request(FinchH1)
Finch.build(:get, "https://127.0.0.1:#{h2_server.port}/1kb") |> Finch.request(FinchH2)

for {path, label} <- [{"/1kb", "1kb"}, {"/100kb", "100kb"}, {"/1mb", "1mb"}] do
  IO.puts("\n--- #{label} payload (parallel: 20, h2 conns: 10 each) ---\n")

  jobs = %{
    "quiver http1" => fn ->
      HTTP1.request(q_h1, :get, path, [], nil)
    end,
    "quiver http2" => fn ->
      HTTP2.request(q_h2, :get, path, [], nil)
    end,
    "finch http1" => fn ->
      Finch.build(:get, "http://127.0.0.1:#{h1_server.port}#{path}")
      |> Finch.request(FinchH1)
    end,
    "finch http2" => fn ->
      Finch.build(:get, "https://127.0.0.1:#{h2_server.port}#{path}")
      |> Finch.request(FinchH2)
    end
  }

  Benchee.run(
    jobs,
    warmup: 2,
    time: 10,
    parallel: 20,
    formatters: [
      Benchee.Formatters.Console,
      {Benchee.Formatters.HTML, file: "bench/output/vs_finch_#{label}.html"}
    ]
  )
end

BenchServer.stop(h1_server)
BenchServer.stop(h2_server)
