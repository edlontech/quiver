defmodule Quiver.Pool.HTTP1.UpgradeTest do
  use Quiver.TestCase.Integration, async: true
  @moduletag :integration

  alias Quiver.Pool.HTTP1, as: Pool
  alias Quiver.Upgrade

  describe "upgrade handling" do
    test "returns {:upgrade, %Upgrade{}} when server sends 101" do
      {:ok, port, listen_socket} = start_upgrade_server()
      {:ok, pool} = start_pool(port)

      result =
        Pool.request(
          pool,
          :get,
          "/ws",
          [{"upgrade", "websocket"}, {"connection", "Upgrade"}],
          nil
        )

      assert {:upgrade, %Upgrade{status: 101} = upgrade} = result
      assert List.keyfind(upgrade.headers, "upgrade", 0) == {"upgrade", "websocket"}
      assert upgrade.transport != nil
      assert upgrade.transport_mod != nil

      GenServer.stop(pool)
      :gen_tcp.close(listen_socket)
    end

    test "upgraded transport is usable for bidirectional communication" do
      {:ok, port, listen_socket} = start_upgrade_server()
      {:ok, pool} = start_pool(port)

      {:upgrade, upgrade} =
        Pool.request(
          pool,
          :get,
          "/ws",
          [{"upgrade", "websocket"}, {"connection", "Upgrade"}],
          nil
        )

      {:ok, transport} = upgrade.transport_mod.send(upgrade.transport, "hello")
      {:ok, _transport, data} = upgrade.transport_mod.recv(transport, 0, 2_000)
      assert data == "hello"

      GenServer.stop(pool)
      :gen_tcp.close(listen_socket)
    end

    test "pool slot is removed after upgrade (connection not reused)" do
      {:ok, port, listen_socket} = start_upgrade_server()
      {:ok, pool} = start_pool(port)

      {:upgrade, _upgrade} =
        Pool.request(
          pool,
          :get,
          "/ws",
          [{"upgrade", "websocket"}, {"connection", "Upgrade"}],
          nil
        )

      poll_until(fn -> Pool.stats(pool).active == 0 end)
      assert Pool.stats(pool).idle == 0

      GenServer.stop(pool)
      :gen_tcp.close(listen_socket)
    end
  end

  defp start_pool(port, opts \\ []) do
    Pool.start_link(origin: {:http, "127.0.0.1", port}, pool_opts: opts)
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
