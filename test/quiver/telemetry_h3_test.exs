defmodule Quiver.TelemetryH3Test do
  use ExUnit.Case, async: false
  @moduletag :integration

  alias Quiver.H3TestServer
  alias Quiver.Pool.HTTP3.Connection

  test "emits :start and :stop around handshake" do
    handler = fn h3_conn, sid, _method, _path, _headers ->
      :quic_h3.send_response(h3_conn, sid, 200, [])
      :quic_h3.send_data(h3_conn, sid, <<>>, true)
    end

    {:ok, server} = H3TestServer.start(handler)
    on_exit(fn -> H3TestServer.stop(server.name) end)

    test_pid = self()

    handler_fn = fn evt, meas, meta, _ ->
      send(test_pid, {:tel, evt, meas, meta})
    end

    id = "h3-test-#{System.unique_integer([:positive])}"

    :ok =
      :telemetry.attach_many(
        id,
        [
          [:quiver, :connection, :http3, :start],
          [:quiver, :connection, :http3, :stop]
        ],
        handler_fn,
        nil
      )

    on_exit(fn -> :telemetry.detach(id) end)

    {:ok, _pid} =
      Connection.start_link(
        origin: {:https, "localhost", server.port},
        config: [verify: :verify_none, cacerts: server.cacerts]
      )

    assert_receive {:tel, [:quiver, :connection, :http3, :start], %{system_time: _},
                    %{origin: _}},
                   2_000

    assert_receive {:tel, [:quiver, :connection, :http3, :stop], %{duration: d},
                    %{origin: _, peer_max_streams: _}},
                   5_000

    assert d > 0
  end

  test "connection_http3_event_prefix/0 returns expected prefix" do
    assert Quiver.Telemetry.connection_http3_event_prefix() == [:quiver, :connection, :http3]
  end
end
