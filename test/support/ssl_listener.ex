defmodule Quiver.Test.SSLListener do
  @moduledoc false

  def start(certs) do
    :ssl.start()

    ssl_opts = [
      :binary,
      active: false,
      reuseaddr: true,
      packet: :raw,
      cert: certs.cert,
      key: certs.key,
      cacerts: certs.cacerts
    ]

    {:ok, listen_socket} = :ssl.listen(0, ssl_opts)
    {:ok, {_, port}} = :ssl.sockname(listen_socket)

    pid = spawn_link(fn -> accept_loop(listen_socket) end)
    :ssl.controlling_process(listen_socket, pid)

    {:ok, port, listen_socket}
  end

  def stop(listen_socket) do
    :ssl.close(listen_socket)
  end

  defp accept_loop(listen_socket) do
    case :ssl.transport_accept(listen_socket, 1_000) do
      {:ok, socket} ->
        handle_accepted(socket)
        accept_loop(listen_socket)

      {:error, :timeout} ->
        accept_loop(listen_socket)

      {:error, :closed} ->
        :ok
    end
  end

  defp handle_accepted(socket) do
    case :ssl.handshake(socket, 5_000) do
      {:ok, ssl_socket} ->
        spawn(fn -> echo_loop(ssl_socket) end)

      {:error, _reason} ->
        :ok
    end
  end

  defp echo_loop(socket) do
    case :ssl.recv(socket, 0, 5_000) do
      {:ok, data} ->
        :ssl.send(socket, data)
        echo_loop(socket)

      {:error, :closed} ->
        :ok

      {:error, _reason} ->
        :ssl.close(socket)
    end
  end
end
