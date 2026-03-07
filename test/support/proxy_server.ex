defmodule Quiver.Test.ProxyServer do
  @moduledoc false

  def start do
    {:ok, listen} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(listen)
    pid = spawn(fn -> accept_loop(listen) end)
    :ok = :gen_tcp.controlling_process(listen, pid)
    {:ok, port, pid}
  end

  def stop(pid) do
    Process.exit(pid, :kill)
  end

  defp accept_loop(listen) do
    case :gen_tcp.accept(listen, 2_000) do
      {:ok, client} ->
        pid = spawn(fn -> handle_client(client) end)
        :gen_tcp.controlling_process(client, pid)
        accept_loop(listen)

      {:error, :timeout} ->
        accept_loop(listen)

      {:error, _} ->
        :ok
    end
  end

  defp handle_client(client) do
    {:ok, data} = read_until_headers(client, "")
    ["CONNECT", authority | _] = String.split(hd(String.split(data, "\r\n")), " ")
    [host, port_str] = String.split(authority, ":")
    port = String.to_integer(port_str)

    {:ok, target} = :gen_tcp.connect(to_charlist(host), port, [:binary, active: false])

    :gen_tcp.send(client, "HTTP/1.1 200 Connection Established\r\n\r\n")

    :inet.setopts(client, active: true)
    :inet.setopts(target, active: true)
    relay_loop(client, target)
  end

  defp relay_loop(client, target) do
    receive do
      {:tcp, ^client, data} ->
        :gen_tcp.send(target, data)
        relay_loop(client, target)

      {:tcp, ^target, data} ->
        :gen_tcp.send(client, data)
        relay_loop(client, target)

      {:tcp_closed, _} ->
        :gen_tcp.close(client)
        :gen_tcp.close(target)
    after
      30_000 ->
        :gen_tcp.close(client)
        :gen_tcp.close(target)
    end
  end

  defp read_until_headers(socket, buffer) do
    {:ok, data} = :gen_tcp.recv(socket, 0, 5_000)
    buffer = buffer <> data

    if String.contains?(buffer, "\r\n\r\n"),
      do: {:ok, buffer},
      else: read_until_headers(socket, buffer)
  end
end
