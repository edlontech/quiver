defmodule Quiver.Pool.HTTP3.SessionTicketTest do
  use ExUnit.Case, async: true

  alias Quiver.Conn.HTTP3, as: ConnHTTP3
  alias Quiver.Pool.HTTP3.SessionTicket

  describe "graceful fallbacks (pure)" do
    test "lifetime/1 returns nil for non-ticket terms" do
      assert SessionTicket.lifetime(:not_a_ticket) == nil
      assert SessionTicket.lifetime({:other_record, 1, 2}) == nil
      assert SessionTicket.lifetime(nil) == nil
    end

    test "max_early_data/1 returns nil for non-ticket terms" do
      assert SessionTicket.max_early_data(:not_a_ticket) == nil
      assert SessionTicket.max_early_data({:other_record, 1, 2}) == nil
    end
  end

  describe "against a real ticket" do
    @describetag :integration

    test "reads positive lifetime and non-negative max_early_data from a captured ticket" do
      handler = fn h3_conn, sid, _method, _path, _headers ->
        :quic_h3.send_response(h3_conn, sid, 200, [])
        :quic_h3.send_data(h3_conn, sid, "ok", true)
      end

      {:ok, server} = Quiver.H3TestServer.start(handler)
      on_exit(fn -> Quiver.H3TestServer.stop(server.name) end)

      {:ok, conn} =
        :quic_h3.connect(~c"localhost", server.port, %{
          sync: true,
          alpn: [<<"h3">>],
          verify: :verify_none,
          cacerts: server.cacerts
        })

      {:ok, h3_headers} =
        ConnHTTP3.build_headers(:get, "/", [], {:https, "localhost", server.port})

      {:ok, _sid} = :quic_h3.request(conn, h3_headers, %{end_stream: true})

      assert_receive {:quic_h3, ^conn, {:session_ticket, ticket}}, 5_000
      assert is_integer(SessionTicket.lifetime(ticket)) and SessionTicket.lifetime(ticket) > 0
      assert SessionTicket.max_early_data(ticket) >= 0
    end
  end
end
