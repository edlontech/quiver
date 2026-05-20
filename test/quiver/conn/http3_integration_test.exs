defmodule Quiver.Conn.HTTP3IntegrationTest do
  use ExUnit.Case, async: false
  @moduletag :integration

  alias Quiver.Conn.HTTP3
  alias Quiver.H3TestServer

  setup do
    handler = fn conn, sid, _method, path, _headers ->
      case path do
        <<"/hello", _::binary>> ->
          :quic_h3.send_response(conn, sid, 200, [{<<"content-type">>, <<"text/plain">>}])
          :quic_h3.send_data(conn, sid, <<"hello from h3">>, true)

        <<"/chunked", _::binary>> ->
          :quic_h3.send_response(conn, sid, 200, [])
          :quic_h3.send_data(conn, sid, "part1-", false)
          :quic_h3.send_data(conn, sid, "part2", true)

        _ ->
          :quic_h3.send_response(conn, sid, 404, [])
          :quic_h3.send_data(conn, sid, <<>>, true)
      end
    end

    {:ok, server} = H3TestServer.start(handler)
    on_exit(fn -> H3TestServer.stop(server.name) end)
    {:ok, server: server}
  end

  test "GET returns body", %{server: server} do
    uri = %URI{scheme: "https", host: "localhost", port: server.port}
    {:ok, conn} = HTTP3.connect(uri, cacerts: server.cacerts, verify: :verify_none)
    assert {:ok, _conn, resp} = HTTP3.request(conn, :get, "/hello", [], nil)
    assert resp.status == 200
    assert resp.body == "hello from h3"
    {:ok, _conn} = HTTP3.close(conn)
  end

  test "404 for unknown path", %{server: server} do
    uri = %URI{scheme: "https", host: "localhost", port: server.port}
    {:ok, conn} = HTTP3.connect(uri, cacerts: server.cacerts, verify: :verify_none)
    assert {:ok, _conn, %{status: 404}} = HTTP3.request(conn, :get, "/missing", [], nil)
    {:ok, _conn} = HTTP3.close(conn)
  end

  test "assembles body across multiple DATA frames", %{server: server} do
    uri = %URI{scheme: "https", host: "localhost", port: server.port}
    {:ok, conn} = HTTP3.connect(uri, cacerts: server.cacerts, verify: :verify_none)
    assert {:ok, _conn, resp} = HTTP3.request(conn, :get, "/chunked", [], nil)
    assert resp.status == 200
    assert resp.body == "part1-part2"
    {:ok, _conn} = HTTP3.close(conn)
  end
end
