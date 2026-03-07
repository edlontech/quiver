alias Quiver.BenchServer
alias Quiver.Pool.HTTP1
alias Quiver.Pool.HTTP2
alias Quiver.Pool.Manager

response_sizes = %{"/1kb" => 1_024, "/100kb" => 102_400, "/1mb" => 1_048_576}

handler = fn conn ->
  {:ok, _body, conn} = Plug.Conn.read_body(conn)
  size = Map.get(response_sizes, conn.request_path, 100)
  Plug.Conn.send_resp(conn, 200, :binary.copy("x", size))
end

payloads = %{
  "1kb" => :binary.copy("x", 1_024),
  "100kb" => :binary.copy("x", 102_400),
  "1mb" => :binary.copy("x", 1_048_576)
}

{:ok, h1_server} = BenchServer.start_http1(handler)
{:ok, h2_server} = BenchServer.start_http2(handler)

h2_tls_opts = [verify: :verify_none, cacerts: h2_server.cacerts]

# -- Quiver pools (shared by both direct and Tesla) --

{:ok, _} =
  Quiver.Supervisor.start_link(
    name: :bench_tesla_h1,
    pools: %{default: [protocol: :http1, size: 30]}
  )

{:ok, _} =
  Quiver.Supervisor.start_link(
    name: :bench_tesla_h2,
    pools: %{default: [protocol: :http2, max_connections: 10] ++ h2_tls_opts}
  )

{:ok, q_h1} = Manager.get_pool(:bench_tesla_h1, {:http, "127.0.0.1", h1_server.port})
{:ok, q_h2} = Manager.get_pool(:bench_tesla_h2, {:https, "127.0.0.1", h2_server.port})

# -- Finch pools (for Tesla+Finch comparison) --

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

Finch.start_link(
  name: FinchH2,
  pools: %{
    "https://127.0.0.1:#{h2_server.port}" => [
      protocols: [:http2],
      count: 10,
      conn_opts: [transport_opts: h2_tls_opts]
    ]
  }
)

# -- Tesla clients --

defmodule BenchTeslaQuiverH1 do
  use Tesla
  adapter(Tesla.Adapter.Quiver, name: :bench_tesla_h1)
end

defmodule BenchTeslaQuiverH2 do
  use Tesla
  adapter(Tesla.Adapter.Quiver, name: :bench_tesla_h2)
end

defmodule BenchTeslaFinchH1 do
  use Tesla
  adapter(Tesla.Adapter.Finch, name: FinchH1)
end

defmodule BenchTeslaFinchH2 do
  use Tesla
  adapter(Tesla.Adapter.Finch, name: FinchH2)
end

File.mkdir_p!("bench/output")
File.mkdir_p!("guides/benchmarks")

# Warm up
HTTP1.request(q_h1, :get, "/1kb", [], nil)
HTTP2.request(q_h2, :get, "/1kb", [], nil)
BenchTeslaQuiverH1.get("http://127.0.0.1:#{h1_server.port}/1kb")
BenchTeslaQuiverH2.get("https://127.0.0.1:#{h2_server.port}/1kb")
BenchTeslaFinchH1.get("http://127.0.0.1:#{h1_server.port}/1kb")
BenchTeslaFinchH2.get("https://127.0.0.1:#{h2_server.port}/1kb")

# -- GET benchmarks --

for {path, label} <- [{"/1kb", "1kb"}, {"/100kb", "100kb"}, {"/1mb", "1mb"}] do
  IO.puts("\n--- GET #{label}: Quiver direct vs Tesla+Quiver vs Tesla+Finch (parallel: 20) ---\n")

  Benchee.run(
    %{
      "quiver http1" => fn ->
        HTTP1.request(q_h1, :get, path, [], nil)
      end,
      "tesla+quiver http1" => fn ->
        BenchTeslaQuiverH1.get("http://127.0.0.1:#{h1_server.port}#{path}")
      end,
      "tesla+finch http1" => fn ->
        BenchTeslaFinchH1.get("http://127.0.0.1:#{h1_server.port}#{path}")
      end,
      "quiver http2" => fn ->
        HTTP2.request(q_h2, :get, path, [], nil)
      end,
      "tesla+quiver http2" => fn ->
        BenchTeslaQuiverH2.get("https://127.0.0.1:#{h2_server.port}#{path}")
      end,
      "tesla+finch http2" => fn ->
        BenchTeslaFinchH2.get("https://127.0.0.1:#{h2_server.port}#{path}")
      end
    },
    warmup: 2,
    time: 10,
    memory_time: 2,
    reduction_time: 2,
    parallel: 20,
    formatters: [
      {Benchee.Formatters.Console, extended_statistics: true},
      {Benchee.Formatters.Markdown, file: "guides/benchmarks/vs_tesla_#{label}.md"},
      {Benchee.Formatters.JSON, file: "bench/output/vs_tesla_#{label}.json"}
    ]
  )
end

# -- POST benchmarks --

for {label, body} <- [
      {"1kb", payloads["1kb"]},
      {"100kb", payloads["100kb"]},
      {"1mb", payloads["1mb"]}
    ] do
  IO.puts(
    "\n--- POST #{label}: Quiver direct vs Tesla+Quiver vs Tesla+Finch (parallel: 20) ---\n"
  )

  headers = [{"content-type", "application/octet-stream"}]

  Benchee.run(
    %{
      "quiver http1" => fn ->
        HTTP1.request(q_h1, :post, "/post", headers, body)
      end,
      "tesla+quiver http1" => fn ->
        BenchTeslaQuiverH1.post("http://127.0.0.1:#{h1_server.port}/post", body, headers: headers)
      end,
      "tesla+finch http1" => fn ->
        BenchTeslaFinchH1.post("http://127.0.0.1:#{h1_server.port}/post", body, headers: headers)
      end,
      "quiver http2" => fn ->
        HTTP2.request(q_h2, :post, "/post", headers, body)
      end,
      "tesla+quiver http2" => fn ->
        BenchTeslaQuiverH2.post("https://127.0.0.1:#{h2_server.port}/post", body,
          headers: headers
        )
      end,
      "tesla+finch http2" => fn ->
        BenchTeslaFinchH2.post("https://127.0.0.1:#{h2_server.port}/post", body, headers: headers)
      end
    },
    warmup: 2,
    time: 10,
    memory_time: 2,
    reduction_time: 2,
    parallel: 20,
    formatters: [
      {Benchee.Formatters.Console, extended_statistics: true},
      {Benchee.Formatters.Markdown, file: "guides/benchmarks/vs_tesla_post_#{label}.md"},
      {Benchee.Formatters.JSON, file: "bench/output/vs_tesla_post_#{label}.json"}
    ]
  )
end

BenchServer.stop(h1_server)
BenchServer.stop(h2_server)
