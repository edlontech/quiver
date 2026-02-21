defmodule Quiver.Test.TCPListener do
  @moduledoc false

  def start(opts \\ []) do
    tcp_opts =
      [
        :binary,
        active: false,
        reuseaddr: true,
        packet: :raw
      ] ++ opts

    {:ok, listen_socket} = :gen_tcp.listen(0, tcp_opts)
    {:ok, port} = :inet.port(listen_socket)

    pid = spawn_link(fn -> accept_loop(listen_socket) end)
    :ok = :gen_tcp.controlling_process(listen_socket, pid)

    {:ok, port, listen_socket}
  end

  def stop(listen_socket) do
    :gen_tcp.close(listen_socket)
  end

  defp accept_loop(listen_socket) do
    case :gen_tcp.accept(listen_socket, 1_000) do
      {:ok, socket} ->
        spawn_link(fn -> echo_loop(socket) end)
        accept_loop(listen_socket)

      {:error, :timeout} ->
        accept_loop(listen_socket)

      {:error, :closed} ->
        :ok
    end
  end

  defp echo_loop(socket) do
    case :gen_tcp.recv(socket, 0, 5_000) do
      {:ok, data} ->
        :gen_tcp.send(socket, data)
        echo_loop(socket)

      {:error, :closed} ->
        :ok

      {:error, _reason} ->
        :gen_tcp.close(socket)
    end
  end
end
