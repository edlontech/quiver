defmodule Quiver.HTTP3.DatagramNegotiationTest do
  use Quiver.TestCase.Integration, async: false

  @moduletag :integration

  alias Quiver.Pool.HTTP3, as: PoolHTTP3
  alias Quiver.Pool.HTTP3.Connection, as: PoolHTTP3Connection
  alias Quiver.Supervisor, as: QuiverSupervisor
  alias Quiver.Test.Certs

  setup do
    server_name = :"datagram_neg_srv_#{System.unique_integer([:positive])}"
    certs = Certs.generate("localhost")

    handler = fn h3_conn, sid, _method, _path, _headers ->
      :quic_h3.send_response(h3_conn, sid, 200, [])
      :quic_h3.send_data(h3_conn, sid, "ok", true)
    end

    {:ok, _pid} =
      :quic_h3.start_server(server_name, 0, %{
        cert: certs.cert,
        key: decode_key(certs.key),
        alpn: [<<"h3">>],
        h3_datagram_enabled: true,
        handler: handler
      })

    {:ok, port} = :quic.get_server_port(server_name)

    on_exit(fn -> :quic_h3.stop_server(server_name) end)

    %{port: port, cacerts: certs.cacerts}
  end

  test "pool with protocol: :http3 negotiates datagrams against a datagram-enabled server", %{
    port: port,
    cacerts: cacerts
  } do
    sup_name = :"datagram_neg_client_#{System.unique_integer([:positive])}"

    start_supervised!(
      {QuiverSupervisor,
       name: sup_name,
       pools: %{
         :default => [
           protocol: :http3,
           verify: :verify_none,
           cacerts: cacerts,
           max_connections: 1
         ]
       }}
    )

    {:ok, %Quiver.Response{status: 200}} =
      :get
      |> Quiver.new("https://localhost:#{port}/")
      |> Quiver.request(name: sup_name)

    registry = QuiverSupervisor.registry_name(sup_name)
    origin = {:https, "localhost", port}

    poll_until(fn -> Registry.lookup(registry, origin) != [] end, 2_000)

    [{pool_pid, _}] = Registry.lookup(registry, origin)

    poll_until(fn -> PoolHTTP3.first_worker(pool_pid) != nil end, 2_000)

    worker_pid = PoolHTTP3.first_worker(pool_pid)
    assert is_pid(worker_pid)

    h3_conn = PoolHTTP3Connection.get_h3_conn(worker_pid)
    assert is_pid(h3_conn)
    assert :quic_h3.h3_datagrams_enabled(h3_conn) == true
  end

  defp decode_key({:RSAPrivateKey, der}) when is_binary(der) do
    :public_key.der_decode(:RSAPrivateKey, der)
  end

  defp decode_key({:ECPrivateKey, der}) when is_binary(der) do
    :public_key.der_decode(:ECPrivateKey, der)
  end

  defp decode_key(other), do: other
end
