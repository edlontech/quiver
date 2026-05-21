defmodule Quiver.Conn.HTTP3Test do
  use ExUnit.Case, async: true

  alias Quiver.Conn.HTTP3

  describe "to_h3_headers/4" do
    test "prepends pseudo-headers in order" do
      conn = %HTTP3{
        host: "example.com",
        port: 443,
        scheme: :https,
        peer_max_streams: 100,
        recv_timeout: 15_000
      }

      assert {:ok, headers} = HTTP3.to_h3_headers(:get, "/path", [], conn)

      assert [
               {<<":method">>, "GET"},
               {<<":scheme">>, "https"},
               {<<":path">>, "/path"},
               {<<":authority">>, "example.com"}
             ] = headers
    end

    test "omits :443 from authority" do
      conn = %HTTP3{
        host: "example.com",
        port: 443,
        scheme: :https,
        peer_max_streams: 100,
        recv_timeout: 15_000
      }

      assert {:ok, [_, _, _, {<<":authority">>, "example.com"}]} =
               HTTP3.to_h3_headers(:get, "/", [], conn)
    end

    test "includes non-default port in authority" do
      conn = %HTTP3{
        host: "example.com",
        port: 8443,
        scheme: :https,
        peer_max_streams: 100,
        recv_timeout: 15_000
      }

      assert {:ok, [_, _, _, {<<":authority">>, "example.com:8443"}]} =
               HTTP3.to_h3_headers(:get, "/", [], conn)
    end

    test "lowercases user headers" do
      conn = %HTTP3{
        host: "h",
        port: 443,
        scheme: :https,
        peer_max_streams: 100,
        recv_timeout: 15_000
      }

      assert {:ok, headers} =
               HTTP3.to_h3_headers(:get, "/", [{"Content-Type", "text/plain"}], conn)

      assert {"content-type", "text/plain"} in headers
    end

    test "rejects forbidden connection-specific headers" do
      conn = %HTTP3{
        host: "h",
        port: 443,
        scheme: :https,
        peer_max_streams: 100,
        recv_timeout: 15_000
      }

      for h <- ~w(Connection Keep-Alive Transfer-Encoding Upgrade Proxy-Connection) do
        assert {:error, {:forbidden_header, _}} =
                 HTTP3.to_h3_headers(:get, "/", [{h, "x"}], conn)
      end
    end
  end

  describe "build_headers/5 with :protocol opt" do
    test "emits :protocol pseudo-header between :method and :scheme" do
      {:ok, headers} =
        HTTP3.build_headers(:connect, "/wt", [], {:https, "example.test", 443},
          protocol: "webtransport"
        )

      assert [
               {":method", "CONNECT"},
               {":protocol", "webtransport"},
               {":scheme", "https"},
               {":path", "/wt"},
               {":authority", "example.test"}
             ] = headers
    end

    test "omits :protocol when nil" do
      {:ok, headers} = HTTP3.build_headers(:get, "/", [], {:https, "x.test", 443})

      refute Enum.any?(headers, fn {k, _} -> k == ":protocol" end)
    end

    test "build_headers/4 and build_headers/5 with nil :protocol produce identical output" do
      {:ok, h4} = HTTP3.build_headers(:get, "/", [{"x-foo", "bar"}], {:https, "x.test", 443})

      {:ok, h5} =
        HTTP3.build_headers(:get, "/", [{"x-foo", "bar"}], {:https, "x.test", 443}, protocol: nil)

      assert h4 == h5
    end
  end

  describe "open?/1" do
    test "false for nil pid" do
      conn = %HTTP3{
        h3_conn: nil,
        host: "h",
        port: 443,
        scheme: :https,
        peer_max_streams: 100,
        recv_timeout: 15_000
      }

      refute HTTP3.open?(conn)
    end

    test "true for live pid" do
      pid = spawn(fn -> :timer.sleep(:infinity) end)

      conn = %HTTP3{
        h3_conn: pid,
        host: "h",
        port: 443,
        scheme: :https,
        peer_max_streams: 100,
        recv_timeout: 15_000
      }

      assert HTTP3.open?(conn)
      Process.exit(pid, :kill)
    end
  end
end
