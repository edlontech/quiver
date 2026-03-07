defmodule Quiver.ProxyTest do
  use ExUnit.Case, async: true

  alias Quiver.Error.ProxyConnectFailed
  alias Quiver.Proxy

  describe "connect_tunnel/5" do
    test "establishes tunnel when proxy returns 200" do
      {:ok, listen_socket, port} = start_proxy_server(200)

      assert {:ok, transport} =
               Proxy.connect_tunnel("127.0.0.1", port, "target.example.com", 443)

      assert %Quiver.Transport.TCP{} = transport

      stop_proxy_server(listen_socket)
    end

    test "sends well-formed CONNECT request" do
      {:ok, listen_socket, port} = start_proxy_server(200, self())

      {:ok, _transport} =
        Proxy.connect_tunnel("127.0.0.1", port, "target.example.com", 443,
          headers: [{"proxy-authorization", "Basic dGVzdDp0ZXN0"}]
        )

      assert_receive {:connect_request, request_data}, 1_000
      assert request_data =~ "CONNECT target.example.com:443 HTTP/1.1\r\n"
      assert request_data =~ "host: target.example.com:443\r\n"
      assert request_data =~ "proxy-authorization: Basic dGVzdDp0ZXN0\r\n"

      stop_proxy_server(listen_socket)
    end

    test "returns error when proxy returns 407" do
      {:ok, listen_socket, port} = start_proxy_server(407)

      assert {:error, %ProxyConnectFailed{status: 407, target: "target.example.com:443"}} =
               Proxy.connect_tunnel("127.0.0.1", port, "target.example.com", 443)

      stop_proxy_server(listen_socket)
    end

    test "returns error when proxy returns 502" do
      {:ok, listen_socket, port} = start_proxy_server(502)

      assert {:error, %ProxyConnectFailed{status: 502}} =
               Proxy.connect_tunnel("127.0.0.1", port, "target.example.com", 443)

      stop_proxy_server(listen_socket)
    end

    test "returns error when proxy is unreachable" do
      assert {:error, _} =
               Proxy.connect_tunnel("127.0.0.1", 1, "target.example.com", 443,
                 connect_timeout: 500
               )
    end
  end

  describe "ProxyConnectFailed error" do
    test "has correct message" do
      error = ProxyConnectFailed.exception(status: 407, target: "proxy.example.com:443")

      assert Exception.message(error) =~
               "proxy CONNECT to proxy.example.com:443 failed with status 407"
    end

    test "is a transient error" do
      error = ProxyConnectFailed.exception(status: 502, target: "host:443")
      assert error.class == :transient
    end
  end

  defp start_proxy_server(status_code, notify_pid \\ nil) do
    {:ok, listen_socket} =
      :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true, packet: :raw])

    {:ok, port} = :inet.port(listen_socket)

    pid = spawn_link(fn -> proxy_accept_loop(listen_socket, status_code, notify_pid) end)
    :ok = :gen_tcp.controlling_process(listen_socket, pid)

    {:ok, listen_socket, port}
  end

  defp stop_proxy_server(listen_socket) do
    :gen_tcp.close(listen_socket)
  end

  defp proxy_accept_loop(listen_socket, status_code, notify_pid) do
    case :gen_tcp.accept(listen_socket, 2_000) do
      {:ok, socket} ->
        spawn_link(fn -> handle_proxy_connection(socket, status_code, notify_pid) end)
        proxy_accept_loop(listen_socket, status_code, notify_pid)

      {:error, :timeout} ->
        proxy_accept_loop(listen_socket, status_code, notify_pid)

      {:error, :closed} ->
        :ok
    end
  end

  defp handle_proxy_connection(socket, status_code, notify_pid) do
    {:ok, data} = read_until_headers(socket, "")

    if notify_pid, do: send(notify_pid, {:connect_request, data})

    reason_phrase = status_reason(status_code)
    response = "HTTP/1.1 #{status_code} #{reason_phrase}\r\n\r\n"
    :gen_tcp.send(socket, response)

    unless status_code >= 200 and status_code < 300 do
      :gen_tcp.close(socket)
    end
  end

  defp read_until_headers(socket, buffer) do
    case :gen_tcp.recv(socket, 0, 2_000) do
      {:ok, data} ->
        buffer = buffer <> data

        if String.contains?(buffer, "\r\n\r\n") do
          {:ok, buffer}
        else
          read_until_headers(socket, buffer)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp status_reason(200), do: "Connection Established"
  defp status_reason(407), do: "Proxy Authentication Required"
  defp status_reason(502), do: "Bad Gateway"
end
