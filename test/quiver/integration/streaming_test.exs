defmodule Quiver.Integration.StreamingTest do
  use Quiver.TestCase.Integration, async: true
  @moduletag :integration

  alias Quiver.TestServer

  defp echo_handler(conn) do
    {:ok, body, conn} = Plug.Conn.read_body(conn, length: 500_000)
    Plug.Conn.send_resp(conn, 200, body)
  end

  defp start_h1_env(_context) do
    name = :"stream_h1_#{System.unique_integer([:positive])}"
    {:ok, server} = TestServer.start(&echo_handler/1)

    {:ok, _} =
      Quiver.Supervisor.start_link(
        name: name,
        pools: %{default: [size: 5]}
      )

    on_exit(fn -> TestServer.stop(server) end)

    %{name: name, port: server.port, scheme: "http"}
  end

  defp start_h2_env(_context) do
    name = :"stream_h2_#{System.unique_integer([:positive])}"

    {:ok, %{port: port, cacerts: cacerts} = server} =
      TestServer.start(&echo_handler/1, https: true, http_2_only: true)

    {:ok, _} =
      Quiver.Supervisor.start_link(
        name: name,
        pools: %{default: [protocol: :http2, verify: :verify_none, cacerts: cacerts]}
      )

    on_exit(fn -> TestServer.stop(server) end)

    %{name: name, port: port, scheme: "https"}
  end

  describe "HTTP/1.1 request body streaming" do
    setup :start_h1_env

    test "streams enumerable body", %{name: name, port: port} do
      chunks = Stream.map(1..5, fn i -> "chunk#{i}" end)

      assert {:ok, %Quiver.Response{status: 200, body: body}} =
               Quiver.new(:post, "http://127.0.0.1:#{port}/")
               |> Quiver.header("transfer-encoding", "chunked")
               |> Quiver.stream_body(chunks)
               |> Quiver.request(name: name)

      assert body == "chunk1chunk2chunk3chunk4chunk5"
    end

    @tag :tmp_dir
    test "streams File.stream body", %{name: name, port: port, tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "upload.txt")
      content = "file content for streaming test"
      File.write!(path, content)

      assert {:ok, %Quiver.Response{status: 200, body: body}} =
               Quiver.new(:post, "http://127.0.0.1:#{port}/")
               |> Quiver.header("transfer-encoding", "chunked")
               |> Quiver.stream_body(File.stream!(path, 64))
               |> Quiver.request(name: name)

      assert body == content
    end

    test "streams large body (128KB)", %{name: name, port: port} do
      chunk = String.duplicate("x", 1_024)
      chunks = Stream.repeatedly(fn -> chunk end) |> Stream.take(128)
      expected_size = 1_024 * 128

      assert {:ok, %Quiver.Response{status: 200, body: body}} =
               Quiver.new(:post, "http://127.0.0.1:#{port}/")
               |> Quiver.header("transfer-encoding", "chunked")
               |> Quiver.stream_body(chunks)
               |> Quiver.request(name: name)

      assert byte_size(body) == expected_size
    end
  end

  describe "HTTP/2 request body streaming" do
    setup :start_h2_env

    test "streams enumerable body", %{name: name, port: port} do
      chunks = ["hello", " ", "streaming", " ", "world"]

      assert {:ok, %Quiver.Response{status: 200, body: body}} =
               Quiver.new(:post, "https://127.0.0.1:#{port}/")
               |> Quiver.header("content-type", "text/plain")
               |> Quiver.stream_body(Stream.map(chunks, & &1))
               |> Quiver.request(name: name)

      assert body == "hello streaming world"
    end

    test "streams large body (128KB)", %{name: name, port: port} do
      chunk = String.duplicate("y", 1_024)
      chunks = Stream.repeatedly(fn -> chunk end) |> Stream.take(128)
      expected_size = 1_024 * 128

      assert {:ok, %Quiver.Response{status: 200, body: body}} =
               Quiver.new(:post, "https://127.0.0.1:#{port}/")
               |> Quiver.header("content-type", "application/octet-stream")
               |> Quiver.stream_body(chunks)
               |> Quiver.request(name: name)

      assert byte_size(body) == expected_size
    end
  end

  describe "streaming body with list" do
    setup :start_h1_env

    test "plain list as stream body", %{name: name, port: port} do
      assert {:ok, %Quiver.Response{status: 200, body: body}} =
               Quiver.new(:post, "http://127.0.0.1:#{port}/")
               |> Quiver.header("transfer-encoding", "chunked")
               |> Quiver.stream_body(["part1", "part2", "part3"])
               |> Quiver.request(name: name)

      assert body == "part1part2part3"
    end
  end

  describe "File.stream integration" do
    setup :start_h2_env

    @tag :tmp_dir
    test "HTTP/2 streams file body", %{name: name, port: port, tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "h2_upload.txt")
      content = String.duplicate("elixir-streaming-", 100)
      File.write!(path, content)

      assert {:ok, %Quiver.Response{status: 200, body: body}} =
               Quiver.new(:post, "https://127.0.0.1:#{port}/")
               |> Quiver.header("content-type", "application/octet-stream")
               |> Quiver.stream_body(File.stream!(path, 256))
               |> Quiver.request(name: name)

      assert body == content
    end
  end
end
