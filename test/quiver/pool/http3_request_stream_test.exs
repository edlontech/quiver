defmodule Quiver.Pool.HTTP3RequestStreamTest do
  use ExUnit.Case, async: false
  @moduletag :integration

  alias Quiver.H3TestServer
  alias Quiver.Pool.HTTP3
  alias Quiver.Response

  setup do
    handler = fn h3_conn, sid, _method, _path, _headers ->
      case :quic_h3.set_stream_handler(h3_conn, sid, self()) do
        :ok ->
          collect_and_echo(h3_conn, sid, [])

        {:ok, buffered} ->
          {acc, done?} = drain_buffered(buffered)
          if done?, do: echo(h3_conn, sid, acc), else: collect_and_echo(h3_conn, sid, acc)
      end
    end

    {:ok, server} = H3TestServer.start(handler)
    on_exit(fn -> H3TestServer.stop(server.name) end)

    {:ok, server: server, config: [verify: :verify_none, cacerts: server.cacerts]}
  end

  test "streams request body chunks to the server", %{server: server, config: config} do
    {:ok, pool} =
      HTTP3.start_link(origin: {:https, "localhost", server.port}, pool_opts: config)

    payload = for i <- 1..100, do: "chunk-#{i}|"
    expected = Enum.join(payload)
    body_stream = Stream.map(payload, & &1)

    assert {:ok, %Response{status: 200, body: body}} =
             HTTP3.request(
               pool,
               :post,
               "/echo-body",
               [{"content-type", "text/plain"}],
               {:stream, body_stream},
               receive_timeout: 5_000
             )

    assert body == expected
  end

  test "raising enumerable fails the request without killing the worker", %{
    server: server,
    config: config
  } do
    {:ok, pool} =
      HTTP3.start_link(origin: {:https, "localhost", server.port}, pool_opts: config)

    body_stream =
      Stream.unfold(0, fn
        0 -> {"first-chunk|", 1}
        1 -> raise "boom"
      end)

    assert {:error, %Quiver.Error.QUICTransportError{reason: {:stream_body_error, _}}} =
             HTTP3.request(
               pool,
               :post,
               "/echo-body",
               [{"content-type", "text/plain"}],
               {:stream, body_stream},
               receive_timeout: 5_000
             )

    assert Process.alive?(pool), "pool died after body-stream crash"
  end

  test "streams large request body without buffering issues", %{server: server, config: config} do
    {:ok, pool} =
      HTTP3.start_link(origin: {:https, "localhost", server.port}, pool_opts: config)

    chunk = String.duplicate("x", 4 * 1024)
    chunks = List.duplicate(chunk, 64)
    expected = IO.iodata_to_binary(chunks)
    body_stream = Stream.map(chunks, & &1)

    assert {:ok, %Response{status: 200, body: body}} =
             HTTP3.request(
               pool,
               :post,
               "/echo-body",
               [{"content-type", "application/octet-stream"}],
               {:stream, body_stream},
               receive_timeout: 10_000
             )

    assert body == expected
  end

  defp collect_and_echo(h3_conn, sid, acc) do
    receive do
      {:quic_h3, ^h3_conn, {:data, ^sid, chunk, false}} ->
        collect_and_echo(h3_conn, sid, [acc, chunk])

      {:quic_h3, ^h3_conn, {:data, ^sid, chunk, true}} ->
        echo(h3_conn, sid, [acc, chunk])
    after
      5_000 -> :timeout
    end
  end

  defp drain_buffered(chunks) do
    Enum.reduce(chunks, {[], false}, fn {data, fin}, {acc, _} -> {[acc, data], fin} end)
  end

  defp echo(h3_conn, sid, body) do
    binary = IO.iodata_to_binary(body)

    :quic_h3.send_response(h3_conn, sid, 200, [
      {<<"content-length">>, Integer.to_string(byte_size(binary))}
    ])

    :quic_h3.send_data(h3_conn, sid, binary, true)
  end
end
