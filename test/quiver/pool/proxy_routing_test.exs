defmodule Quiver.Pool.ProxyRoutingTest do
  use Quiver.TestCase.Integration, async: false

  alias Quiver.Test.ProxyServer
  alias Quiver.TestServer

  @moduletag :integration

  describe "HTTP/1.1 HTTPS through CONNECT proxy" do
    test "routes request through proxy tunnel" do
      {:ok, target} =
        TestServer.start(
          fn conn ->
            Plug.Conn.send_resp(conn, 200, "tunneled-http1")
          end,
          https: true
        )

      {:ok, proxy_port, proxy_pid} = ProxyServer.start()

      try do
        name = :"proxy_http1_#{System.unique_integer([:positive])}"

        {:ok, _sup} =
          Quiver.Supervisor.start_link(
            name: name,
            pools: %{
              :default => [
                protocol: :http1,
                size: 1,
                verify: :verify_none,
                proxy: [host: "127.0.0.1", port: proxy_port]
              ]
            }
          )

        url = "https://127.0.0.1:#{target.port}/test"

        assert {:ok, response} =
                 Quiver.request(
                   %Quiver.Request{method: :get, url: URI.parse(url)},
                   name: name
                 )

        assert response.status == 200
        assert response.body == "tunneled-http1"
      after
        ProxyServer.stop(proxy_pid)
        TestServer.stop(target)
      end
    end
  end

  describe "HTTP/2 HTTPS through CONNECT proxy" do
    test "routes request through proxy tunnel" do
      {:ok, target} =
        TestServer.start(
          fn conn ->
            Plug.Conn.send_resp(conn, 200, "tunneled-h2")
          end,
          https: true,
          http_2_only: true
        )

      {:ok, proxy_port, proxy_pid} = ProxyServer.start()

      try do
        name = :"proxy_h2_#{System.unique_integer([:positive])}"

        {:ok, _sup} =
          Quiver.Supervisor.start_link(
            name: name,
            pools: %{
              :default => [
                protocol: :http2,
                verify: :verify_none,
                proxy: [host: "127.0.0.1", port: proxy_port]
              ]
            }
          )

        url = "https://127.0.0.1:#{target.port}/test"

        assert {:ok, response} =
                 Quiver.request(
                   %Quiver.Request{method: :get, url: URI.parse(url)},
                   name: name
                 )

        assert response.status == 200
        assert response.body == "tunneled-h2"
      after
        ProxyServer.stop(proxy_pid)
        TestServer.stop(target)
      end
    end
  end
end
