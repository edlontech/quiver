defmodule Quiver.Conn.HTTP1.UpgradeTest do
  use ExUnit.Case, async: true

  alias Quiver.Conn.HTTP1
  alias Quiver.Upgrade

  describe "101 Switching Protocols" do
    test "returns {:upgrade, conn, %Upgrade{}} with transport" do
      {:ok, port, listen_socket} = start_upgrade_server()

      uri = URI.parse("http://127.0.0.1:#{port}")
      {:ok, conn} = HTTP1.connect(uri, [])

      result =
        HTTP1.request(
          conn,
          :get,
          "/ws",
          [{"upgrade", "websocket"}, {"connection", "Upgrade"}],
          nil
        )

      assert {:upgrade, conn, %Upgrade{} = upgrade} = result
      assert upgrade.status == 101
      assert List.keyfind(upgrade.headers, "upgrade", 0) == {"upgrade", "websocket"}
      assert upgrade.transport == conn.transport
      assert upgrade.transport_mod == conn.transport_mod
      refute HTTP1.open?(conn)

      :gen_tcp.close(listen_socket)
    end

    test "upgrade transport is usable for bidirectional communication" do
      {:ok, port, listen_socket} = start_upgrade_server()

      uri = URI.parse("http://127.0.0.1:#{port}")
      {:ok, conn} = HTTP1.connect(uri, [])

      {:upgrade, _conn, upgrade} =
        HTTP1.request(
          conn,
          :get,
          "/ws",
          [{"upgrade", "websocket"}, {"connection", "Upgrade"}],
          nil
        )

      {:ok, transport} = upgrade.transport_mod.send(upgrade.transport, "ping")
      {:ok, _transport, data} = upgrade.transport_mod.recv(transport, 0, 2_000)
      assert data == "ping"

      :gen_tcp.close(listen_socket)
    end

    test "non-101 responses still return {:ok, conn, response}" do
      {:ok, %{port: port} = raw_server} =
        Quiver.TestServer.start_raw(fn _data ->
          "HTTP/1.1 200 OK\r\ncontent-length: 2\r\n\r\nok"
        end)

      uri = URI.parse("http://127.0.0.1:#{port}")
      {:ok, conn} = HTTP1.connect(uri, [])

      assert {:ok, _conn, %Quiver.Response{status: 200}} =
               HTTP1.request(conn, :get, "/", [], nil)

      Quiver.TestServer.stop(raw_server)
    end
  end

  defp start_upgrade_server do
    {:ok, listen_socket} =
      :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true, packet: :raw])

    {:ok, port} = :inet.port(listen_socket)
    pid = spawn_link(fn -> accept_loop(listen_socket) end)
    :ok = :gen_tcp.controlling_process(listen_socket, pid)

    {:ok, port, listen_socket}
  end

  defp accept_loop(listen_socket) do
    case :gen_tcp.accept(listen_socket, 2_000) do
      {:ok, socket} ->
        spawn_link(fn -> handle_upgrade(socket) end)
        accept_loop(listen_socket)

      {:error, :timeout} ->
        accept_loop(listen_socket)

      {:error, _} ->
        :ok
    end
  end

  defp handle_upgrade(socket) do
    {:ok, _data} = :gen_tcp.recv(socket, 0, 5_000)

    response =
      "HTTP/1.1 101 Switching Protocols\r\n" <>
        "upgrade: websocket\r\n" <>
        "connection: Upgrade\r\n" <>
        "\r\n"

    :gen_tcp.send(socket, response)
    echo_loop(socket)
  end

  defp echo_loop(socket) do
    case :gen_tcp.recv(socket, 0, 5_000) do
      {:ok, data} ->
        :gen_tcp.send(socket, data)
        echo_loop(socket)

      {:error, _} ->
        :gen_tcp.close(socket)
    end
  end
end
