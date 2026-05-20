# Quiver HTTP/2 vs Quiver HTTP/3 on the same workload.
#
# Finch has no HTTP/3 support as of writing, so the protocol comparison is
# kept inside Quiver only. The HTTP/2 side is served by Bandit over TLS
# (`BenchServer.start_http2`); the HTTP/3 side is served by a small
# `:quic_h3` server defined inline in this script.
#
# Set `BENCH_SMOKE=1` for a fast smoke-test run (1s warmup, 2s per scenario).

Logger.configure(level: :warning)

alias Quiver.BenchServer
alias Quiver.Pool.HTTP2
alias Quiver.Pool.HTTP3
alias Quiver.Pool.Manager

# -- shared payload sizes --

response_sizes = %{"/1kb" => 1_024, "/1mb" => 1_048_576}

payloads = %{
  "1kb" => :binary.copy("x", 1_024),
  "1mb" => :binary.copy("x", 1_048_576)
}

# -- HTTP/2 server (Bandit) --

h2_handler = fn conn ->
  {:ok, _body, conn} = Plug.Conn.read_body(conn, length: 16 * 1_024 * 1_024)
  size = Map.get(response_sizes, conn.request_path, 100)
  Plug.Conn.send_resp(conn, 200, :binary.copy("x", size))
end

{:ok, h2_server} = BenchServer.start_http2(h2_handler)
h2_tls_opts = [verify: :verify_none, cacerts: h2_server.cacerts]

# -- HTTP/3 server (:quic_h3) --

defmodule Quiver.BenchH3Certs do
  @moduledoc false

  @san_oid {2, 5, 29, 17}
  @rsa_key {:rsa, 2048, 65_537}

  def generate(hostname \\ "localhost") do
    san = {:Extension, @san_oid, false, [{:dNSName, to_charlist(hostname)}]}

    result =
      :public_key.pkix_test_data(%{
        server_chain: %{
          root: [{:key, @rsa_key}],
          intermediates: [],
          peer: [{:key, @rsa_key}, {:extensions, [san]}]
        },
        client_chain: %{root: [], intermediates: [], peer: []}
      })

    server = result.server_config
    %{cert: server[:cert], key: decode_key(server[:key]), cacerts: server[:cacerts]}
  end

  defp decode_key({:RSAPrivateKey, der}) when is_binary(der) do
    :public_key.der_decode(:RSAPrivateKey, der)
  end

  defp decode_key({:ECPrivateKey, der}) when is_binary(der) do
    :public_key.der_decode(:ECPrivateKey, der)
  end

  defp decode_key(other), do: other
end

h3_certs = Quiver.BenchH3Certs.generate("localhost")
h3_server_name = :bench_h3_server

# Match the client's wide flow control windows on the server side. Without
# this, 20-way parallel 1 MB GETs blow the server's default 8 MB connection
# max_data within seconds and the bench kills every QUIC connection with
# `flow_control_blocked` / `:quic_closed` cascades.
h3_quic_opts = %{
  max_data: 256 * 1_024 * 1_024,
  max_stream_data_bidi_local: 16 * 1_024 * 1_024,
  max_stream_data_bidi_remote: 16 * 1_024 * 1_024,
  max_stream_data_uni: 16 * 1_024 * 1_024
}

defmodule Quiver.BenchH3Handler do
  @moduledoc false

  def respond(conn, sid, method, path, response_sizes) do
    if method in [<<"POST">>, <<"PUT">>, <<"PATCH">>] do
      had_fin = consume_initial_buffer(conn, sid)
      unless had_fin, do: drain_body(conn, sid)
    end

    size = Map.get(response_sizes, path, 100)
    :quic_h3.send_response(conn, sid, 200, [])
    :quic_h3.send_data(conn, sid, :binary.copy("x", size), true)
  end

  defp consume_initial_buffer(conn, sid) do
    case :quic_h3.set_stream_handler(conn, sid, self()) do
      :ok -> false
      {:ok, chunks} -> Enum.any?(chunks, fn {_data, fin} -> fin end)
      {:error, _} -> true
    end
  end

  defp drain_body(conn, sid) do
    receive do
      {:quic_h3, ^conn, {:data, ^sid, _data, true}} -> :ok
      {:quic_h3, ^conn, {:data, ^sid, _data, false}} -> drain_body(conn, sid)
    after
      5_000 -> :ok
    end
  end
end

h3_handler = fn h3_conn, sid, method, path, _headers ->
  Quiver.BenchH3Handler.respond(h3_conn, sid, method, path, response_sizes)
end

{:ok, _h3_server_pid} =
  :quic_h3.start_server(h3_server_name, 0, %{
    cert: h3_certs.cert,
    key: h3_certs.key,
    handler: h3_handler,
    alpn: [<<"h3">>],
    quic_opts: h3_quic_opts
  })

{:ok, h3_port} = :quic.get_server_port(h3_server_name)

# -- Quiver pools --

{:ok, _} =
  Quiver.Supervisor.start_link(
    name: :bench_h3_vs_h2_h2,
    pools: %{default: [protocol: :http2, max_connections: 4] ++ h2_tls_opts}
  )

{:ok, q_h2} = Manager.get_pool(:bench_h3_vs_h2_h2, {:https, "127.0.0.1", h2_server.port})

h3_pool_opts =
  # Wide QUIC flow control windows so concurrent 1 MB GETs don't stall on the
  # bench's naive `send_data` server handler. quic_h3 returns a fail-fast
  # `flow_control_blocked` error if a single send exceeds the peer's
  # advertised window; with 20 parallel callers each pulling 1 MB across 4
  # connections we need plenty of headroom both per-stream and per-connection.
  [
    protocol: :http3,
    max_connections: 4,
    verify: :verify_none,
    cacerts: h3_certs.cacerts,
    quic_opts: h3_quic_opts
  ]

# Each scenario starts and stops its own H3 supervisor/pool. Sustained 1 MB
# GET traffic accumulates flow control state on the QUIC connection that
# eventually makes follow-on scenarios stall — restarting between scenarios
# keeps the numbers comparable instead of letting earlier work poison later.
fresh_h3_pool = fn ->
  sup_name = :"bench_h3_#{System.unique_integer([:positive])}"
  {:ok, sup} = Quiver.Supervisor.start_link(name: sup_name, pools: %{default: h3_pool_opts})
  {:ok, pool} = Manager.get_pool(sup_name, {:https, "localhost", h3_port})

  HTTP3.request(pool, :get, "/1kb", [], nil)

  {sup, pool}
end

File.mkdir_p!("bench/output")
File.mkdir_p!("guides/benchmarks")

smoke? = System.get_env("BENCH_SMOKE") == "1"
warmup_secs = if smoke?, do: 1, else: 2
time_secs = if smoke?, do: 2, else: 5
memory_secs = if smoke?, do: 1, else: 2
reduction_secs = if smoke?, do: 1, else: 2

HTTP2.request(q_h2, :get, "/1kb", [], nil)

run_scenario = fn label, h2_fn, h3_fn ->
  {h3_sup, q_h3} = fresh_h3_pool.()

  try do
    Benchee.run(
      %{
        "quiver http2" => fn -> h2_fn.() end,
        "quiver http3" => fn -> h3_fn.(q_h3) end
      },
      warmup: warmup_secs,
      time: time_secs,
      memory_time: memory_secs,
      reduction_time: reduction_secs,
      parallel: 20,
      formatters: [
        {Benchee.Formatters.Console, extended_statistics: true},
        {Benchee.Formatters.Markdown, file: "guides/benchmarks/http3_#{label}.md"},
        {Benchee.Formatters.JSON, file: "bench/output/http3_#{label}.json"}
      ]
    )
  after
    Supervisor.stop(h3_sup)
  end
end

try do
  for {path, label} <- [{"/1kb", "get_1kb_p20"}, {"/1mb", "get_1mb_p20"}] do
    IO.puts("\n--- HTTP/2 vs HTTP/3 GET #{path} (parallel: 20) ---\n")

    run_scenario.(
      label,
      fn -> HTTP2.request(q_h2, :get, path, [], nil) end,
      fn pool -> HTTP3.request(pool, :get, path, [], nil) end
    )
  end

  IO.puts("\n--- HTTP/2 vs HTTP/3 POST post_1kb_p20 ---\n")
  post_body = payloads["1kb"]
  post_headers = [{"content-type", "application/octet-stream"}]

  run_scenario.(
    "post_1kb_p20",
    fn -> HTTP2.request(q_h2, :post, "/post", post_headers, post_body) end,
    fn pool -> HTTP3.request(pool, :post, "/post", post_headers, post_body) end
  )
after
  BenchServer.stop(h2_server)
  :quic_h3.stop_server(h3_server_name)
end
