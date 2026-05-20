defmodule Quiver.HTTP3IntegrationTest do
  use ExUnit.Case, async: false
  @moduletag :integration

  alias Quiver.H3TestServer
  alias Quiver.Pool.Manager

  setup do
    handler = fn h3_conn, sid, method, path, _headers ->
      :quic_h3.send_response(h3_conn, sid, 200, [])
      :quic_h3.send_data(h3_conn, sid, "via Quiver: #{method} #{path}", true)
    end

    {:ok, server} = H3TestServer.start(handler)
    on_exit(fn -> H3TestServer.stop(server.name) end)

    name = :"http3_int_#{System.unique_integer([:positive])}"

    start_supervised!(
      {Quiver.Supervisor,
       name: name,
       pools: %{
         :default => [
           protocol: :http3,
           verify: :verify_none,
           cacerts: server.cacerts
         ]
       }}
    )

    {:ok, server: server, name: name}
  end

  test "Quiver.request/2 routes h3 requests", %{server: server, name: name} do
    assert {:ok, resp} =
             Quiver.new(:get, "https://localhost:#{server.port}/x")
             |> Quiver.request(name: name)

    assert resp.status == 200
    assert resp.body == "via Quiver: GET /x"
  end

  test "POST with a body sends HEADERS without FIN then DATA with FIN", %{
    server: server,
    name: name
  } do
    body = :binary.copy("p", 1_024)

    assert {:ok, resp} =
             Quiver.new(:post, "https://localhost:#{server.port}/post")
             |> Quiver.body(body)
             |> Quiver.request(name: name)

    assert resp.status == 200
    assert resp.body == "via Quiver: POST /post"

    # If the client had sent HEADERS with FIN followed by DATA with FIN, the
    # server would have raised final_size_error and torn the connection down,
    # so a second request on the same pool would fail. Issue another POST to
    # prove the connection survives.
    assert {:ok, resp2} =
             Quiver.new(:post, "https://localhost:#{server.port}/post2")
             |> Quiver.body(body)
             |> Quiver.request(name: name)

    assert resp2.status == 200
    assert resp2.body == "via Quiver: POST /post2"
  end

  test "Manager.pool_stats works for HTTP/3 pool", %{server: server, name: name} do
    {:ok, _} =
      Quiver.new(:get, "https://localhost:#{server.port}/y")
      |> Quiver.request(name: name)

    origin = {:https, "localhost", server.port}
    assert {:ok, stats} = Manager.pool_stats(name, origin)
    assert stats.connections >= 1
  end
end
