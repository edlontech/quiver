defmodule Quiver.Pool.HTTP3StreamTest do
  use ExUnit.Case, async: false
  @moduletag :integration

  alias Quiver.H3TestServer
  alias Quiver.Pool.HTTP3
  alias Quiver.StreamResponse

  setup do
    handler = fn h3_conn, sid, _method, _path, _headers ->
      :quic_h3.send_response(h3_conn, sid, 200, [])
      :quic_h3.send_data(h3_conn, sid, "chunk1", false)
      :quic_h3.send_data(h3_conn, sid, "chunk2", false)
      :quic_h3.send_data(h3_conn, sid, "chunk3", true)
    end

    {:ok, server} = H3TestServer.start(handler)
    on_exit(fn -> H3TestServer.stop(server.name) end)

    {:ok, server: server, config: [verify: :verify_none, cacerts: server.cacerts]}
  end

  test "stream_request yields chunks via Stream.resource", %{server: server, config: config} do
    {:ok, pool} =
      HTTP3.start_link(origin: {:https, "localhost", server.port}, pool_opts: config)

    assert {:ok, %StreamResponse{status: 200, body: stream}} =
             HTTP3.stream_request(pool, :get, "/stream", [], nil, receive_timeout: 5_000)

    chunks = Enum.to_list(stream)
    assert IO.iodata_to_binary(chunks) == "chunk1chunk2chunk3"
  end

  test "halting the stream cancels the request", %{server: server, config: config} do
    {:ok, pool} =
      HTTP3.start_link(origin: {:https, "localhost", server.port}, pool_opts: config)

    assert {:ok, %StreamResponse{body: stream}} =
             HTTP3.stream_request(pool, :get, "/stream", [], nil, receive_timeout: 5_000)

    assert [_first] = Enum.take(stream, 1)

    deadline = System.monotonic_time(:millisecond) + 1_000
    wait_until_active_zero(pool, deadline)

    assert %{active: 0} = HTTP3.stats(pool)
  end

  test "idle stream times out when consumer stops demanding" do
    handler = fn h3_conn, sid, _method, _path, _headers ->
      :quic_h3.send_response(h3_conn, sid, 200, [])
      :quic_h3.send_data(h3_conn, sid, "first", false)
      Process.sleep(:infinity)
    end

    {:ok, server} = Quiver.H3TestServer.start(handler)
    on_exit(fn -> Quiver.H3TestServer.stop(server.name) end)

    config = [verify: :verify_none, cacerts: server.cacerts, stream_idle_timeout: 250]

    {:ok, pool} =
      HTTP3.start_link(origin: {:https, "localhost", server.port}, pool_opts: config)

    {:ok, %StreamResponse{status: 200, body: stream}} =
      HTTP3.stream_request(pool, :get, "/idle", [], nil, receive_timeout: 5_000)

    assert_raise Quiver.Error.StreamError, fn -> Enum.to_list(stream) end

    deadline = System.monotonic_time(:millisecond) + 1_000
    wait_until_active_zero(pool, deadline)

    assert %{active: 0} = HTTP3.stats(pool)
  end

  defp wait_until_active_zero(pool, deadline) do
    if HTTP3.stats(pool).active == 0 do
      :ok
    else
      if System.monotonic_time(:millisecond) >= deadline do
        :ok
      else
        Process.sleep(20)
        wait_until_active_zero(pool, deadline)
      end
    end
  end
end
