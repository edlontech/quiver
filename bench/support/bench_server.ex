defmodule Quiver.BenchServer do
  @moduledoc false

  @san_oid {2, 5, 29, 17}
  @rsa_key {:rsa, 2048, 65_537}

  @doc false
  @spec start_http1((Plug.Conn.t() -> Plug.Conn.t())) :: {:ok, map()}
  def start_http1(handler) do
    {:ok, agent} = Agent.start(fn -> handler end)
    plug = {__MODULE__.Plug, agent: agent}

    {:ok, pid} =
      Bandit.start_link(plug: plug, port: 0, ip: :loopback, startup_log: false)

    {:ok, {_ip, port}} = ThousandIsland.listener_info(pid)
    {:ok, %{port: port, server: pid, agent: agent, cacerts: nil}}
  end

  @doc false
  @spec start_http2((Plug.Conn.t() -> Plug.Conn.t())) :: {:ok, map()}
  def start_http2(handler) do
    certs = generate_certs()
    {:ok, agent} = Agent.start(fn -> handler end)
    plug = {__MODULE__.Plug, agent: agent}

    {:ok, pid} =
      Bandit.start_link(
        plug: plug,
        port: 0,
        ip: :loopback,
        startup_log: false,
        scheme: :https,
        http_1_options: [enabled: false],
        http_2_options: [max_reset_stream_rate: {50_000, 10_000}],
        thousand_island_options: [
          transport_options: [cert: certs.cert, key: certs.key, cacerts: certs.cacerts]
        ]
      )

    {:ok, {_ip, port}} = ThousandIsland.listener_info(pid)
    {:ok, %{port: port, server: pid, agent: agent, cacerts: certs.cacerts}}
  end

  @doc false
  @spec stop(map()) :: :ok
  def stop(%{server: pid, agent: agent}) do
    GenServer.stop(pid)
    Agent.stop(agent)
  end

  defp generate_certs do
    san = {:Extension, @san_oid, false, [{:iPAddress, <<127, 0, 0, 1>>}]}

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
    %{cert: server[:cert], key: server[:key], cacerts: server[:cacerts]}
  end
end

defmodule Quiver.BenchServer.Plug do
  @moduledoc false
  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    handler = Agent.get(opts[:agent], & &1)
    handler.(conn)
  end
end
