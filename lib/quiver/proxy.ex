defmodule Quiver.Proxy do
  @moduledoc """
  HTTP CONNECT tunnel establishment.
  """

  alias Quiver.Error.ProxyConnectFailed
  alias Quiver.Transport.TCP

  @spec connect_tunnel(
          String.t(),
          :inet.port_number(),
          String.t(),
          :inet.port_number(),
          keyword()
        ) ::
          {:ok, TCP.t()} | {:error, term()}
  def connect_tunnel(proxy_host, proxy_port, target_host, target_port, opts \\ []) do
    proxy_headers = Keyword.get(opts, :headers, [])
    connect_timeout = Keyword.get(opts, :connect_timeout, 5_000)
    recv_timeout = Keyword.get(opts, :recv_timeout, 15_000)

    authority = "#{target_host}:#{target_port}"
    headers = [{"host", authority} | proxy_headers]
    request_line = "CONNECT #{authority} HTTP/1.1\r\n"
    header_lines = Enum.map(headers, fn {name, value} -> [name, ": ", value, "\r\n"] end)
    payload = [request_line, header_lines, "\r\n"]

    with {:ok, transport} <- TCP.connect(proxy_host, proxy_port, connect_timeout: connect_timeout),
         {:ok, transport} <- TCP.send(transport, payload),
         {:ok, transport, status} <- read_connect_response(transport, recv_timeout) do
      if status >= 200 and status < 300 do
        {:ok, transport}
      else
        TCP.close(transport)
        {:error, ProxyConnectFailed.exception(status: status, target: authority)}
      end
    end
  end

  defp read_connect_response(transport, timeout) do
    read_until_headers_end(transport, timeout, "")
  end

  defp read_until_headers_end(transport, timeout, buffer) do
    case TCP.recv(transport, 0, timeout) do
      {:ok, transport, data} ->
        buffer = buffer <> data

        if String.contains?(buffer, "\r\n\r\n") do
          [status_line | _] = String.split(buffer, "\r\n", parts: 2)
          [_, status_str | _] = String.split(status_line, " ", parts: 3)
          {:ok, transport, String.to_integer(status_str)}
        else
          read_until_headers_end(transport, timeout, buffer)
        end

      {:error, transport, reason} ->
        {:error, transport, reason}
    end
  end
end
