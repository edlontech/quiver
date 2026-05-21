defmodule Quiver.Pool.HTTP3.Connection.DatagramTest do
  use Quiver.TestCase.Integration, async: false

  @moduletag :integration

  alias Quiver.HTTP3.Channel
  alias Quiver.Pool.HTTP3.Connection
  alias Quiver.Test.Certs

  setup do
    test_pid = self()
    server_name = :"datagram_worker_srv_#{System.unique_integer([:positive])}"
    certs = Certs.generate("localhost")

    handler = fn h3_conn, sid, _method, "/echo", _headers ->
      :quic_h3.send_response(h3_conn, sid, 200, [])
      send(test_pid, {:server_ready, h3_conn, sid})
      :ok
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

  test "open_channel + server-pushed datagram + cancel cleanly stops", %{
    port: port,
    cacerts: cacerts
  } do
    origin = {:https, "localhost", port}

    {:ok, worker} =
      Connection.start_link(
        origin: origin,
        config: [verify: :verify_none, cacerts: cacerts, h3_datagram_enabled: true],
        pool_pid: self()
      )

    assert_receive {:connection_ready, ^worker, _peer_max_streams}, 5_000

    tag = make_ref()
    send(worker, {:forward_open_channel, {self(), tag}, :get, "/echo", [], []})

    assert_receive {^tag, {:ok, %Channel{} = channel, cref}}, 5_000
    assert is_reference(cref)
    assert channel.worker_pid == worker
    assert channel.origin == origin
    assert is_integer(channel.stream_id)

    assert_receive {:quiver_h3_channel, ^cref, {:response, 200, _hs}}, 5_000

    assert_receive {:server_ready, server_conn, server_sid}, 5_000

    :ok = :quic_h3.send_datagram(server_conn, server_sid, "hello-from-server")

    assert_receive {:quiver_h3_channel, ^cref, {:datagram, "hello-from-server"}}, 5_000

    send(worker, {:cancel_stream, cref, self()})

    assert_receive {:stream_done, ^worker}, 5_000

    Process.exit(worker, :normal)
  end

  @tag :skip
  @tag :pending
  test "GOAWAY mid-channel surfaces {:closed, {:goaway, _}} to the channel owner" do
    # Pending (Task 4): drive GOAWAY from the server side and assert the channel
    # owner receives {:quiver_h3_channel, ^cref, {:closed, {:goaway, _gid}}}.
    # Postponed because :quic_h3.start_server/3 alone does not expose a
    # GOAWAY trigger; the full H3DatagramTestServer fixture in Task 4 will.
    flunk("Pending: GOAWAY-driven scenarios are covered by the Task 4 full integration suite")
  end

  defp decode_key({:RSAPrivateKey, der}) when is_binary(der) do
    :public_key.der_decode(:RSAPrivateKey, der)
  end

  defp decode_key({:ECPrivateKey, der}) when is_binary(der) do
    :public_key.der_decode(:ECPrivateKey, der)
  end

  defp decode_key(other), do: other
end
