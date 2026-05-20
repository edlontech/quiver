defmodule Quiver.Pool.HTTP3.ConnectionTest do
  use ExUnit.Case, async: false
  @moduletag :integration

  alias Quiver.Error.H3StreamError
  alias Quiver.H3TestServer
  alias Quiver.Pool.HTTP3.Connection
  alias Quiver.Response

  setup do
    handler = fn h3_conn, sid, _method, path, _headers ->
      case path do
        <<"/echo/", body::binary>> ->
          :quic_h3.send_response(h3_conn, sid, 200, [])
          :quic_h3.send_data(h3_conn, sid, body, true)

        <<"/empty">> ->
          :quic_h3.send_response(h3_conn, sid, 204, [])
          :quic_h3.send_data(h3_conn, sid, <<>>, true)

        <<"/multi">> ->
          :quic_h3.send_response(h3_conn, sid, 200, [])
          :quic_h3.send_data(h3_conn, sid, "part1-", false)
          :quic_h3.send_data(h3_conn, sid, "part2", true)

        <<"/reset">> ->
          :quic_h3.send_response(h3_conn, sid, 200, [])
          :quic_h3.cancel(h3_conn, sid, 0x010C)

        _ ->
          :quic_h3.send_response(h3_conn, sid, 404, [])
          :quic_h3.send_data(h3_conn, sid, <<>>, true)
      end
    end

    {:ok, server} = H3TestServer.start(handler)
    on_exit(fn -> H3TestServer.stop(server.name) end)

    config = [verify: :verify_none, cacerts: server.cacerts]
    {:ok, server: server, config: config}
  end

  defp send_forward_request(pid, method, path, headers \\ [], body \\ nil, timeout \\ 5_000) do
    ref = make_ref()
    send(pid, {:forward_request, {self(), ref}, method, path, headers, body, timeout})
    ref
  end

  test "buffered GET round-trip", %{server: server, config: config} do
    {:ok, pid} =
      Connection.start_link(
        origin: {:https, "localhost", server.port},
        config: config,
        pool_pid: self()
      )

    ref = send_forward_request(pid, :get, "/echo/hello")

    assert_receive {^ref, {:ok, %Response{status: 200, body: "hello"}}}, 5_000
    assert_receive {:stream_done, ^pid}, 1_000
  end

  test "buffers requests fired during :connecting", %{server: server, config: config} do
    {:ok, pid} =
      Connection.start_link(
        origin: {:https, "localhost", server.port},
        config: config,
        pool_pid: self()
      )

    refs =
      for i <- 1..3 do
        send_forward_request(pid, :get, "/echo/r#{i}")
      end

    [r1, r2, r3] = refs
    assert_receive {^r1, {:ok, %Response{status: 200, body: "r1"}}}, 5_000
    assert_receive {^r2, {:ok, %Response{status: 200, body: "r2"}}}, 5_000
    assert_receive {^r3, {:ok, %Response{status: 200, body: "r3"}}}, 5_000

    for _ <- 1..3, do: assert_receive({:stream_done, ^pid}, 1_000)
  end

  test "assembles multi-chunk response body", %{server: server, config: config} do
    {:ok, pid} =
      Connection.start_link(
        origin: {:https, "localhost", server.port},
        config: config,
        pool_pid: self()
      )

    ref = send_forward_request(pid, :get, "/multi")
    assert_receive {^ref, {:ok, %Response{status: 200, body: "part1-part2"}}}, 5_000
    assert_receive {:stream_done, ^pid}, 1_000
  end

  @tag :skip
  test "replies with H3StreamError on stream reset", %{server: server, config: config} do
    {:ok, pid} =
      Connection.start_link(
        origin: {:https, "localhost", server.port},
        config: config,
        pool_pid: self()
      )

    ref = send_forward_request(pid, :get, "/reset")
    assert_receive {^ref, {:error, %H3StreamError{}}}, 5_000
    assert_receive {:stream_done, ^pid}, 1_000
  end

  test "max_streams returns peer transport param after :connected", %{
    server: server,
    config: config
  } do
    {:ok, pid} =
      Connection.start_link(
        origin: {:https, "localhost", server.port},
        config: config,
        pool_pid: self()
      )

    # Issue a buffered request to confirm the worker has reached :connected.
    ref = send_forward_request(pid, :get, "/empty")
    assert_receive {^ref, {:ok, %Response{status: 204}}}, 5_000

    max = Connection.max_streams(pid)
    assert is_integer(max)
    assert max > 0
  end
end
