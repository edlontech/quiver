defmodule Quiver.Transport.TCPTest do
  use ExUnit.Case, async: true

  alias Quiver.Error.ConnectionRefused
  alias Quiver.Error.DNSResolutionFailed
  alias Quiver.Error.Timeout
  alias Quiver.Test.TCPListener
  alias Quiver.Transport.TCP

  setup do
    {:ok, port, listen_socket} = TCPListener.start()
    on_exit(fn -> TCPListener.stop(listen_socket) end)
    %{port: port}
  end

  describe "connect/3" do
    test "connects to a listening port", %{port: port} do
      assert {:ok, %TCP{}} = TCP.connect("127.0.0.1", port, [])
    end

    test "returns error for connection refused" do
      assert {:error, %ConnectionRefused{}} = TCP.connect("127.0.0.1", 1, [])
    end

    test "returns error for DNS resolution failure" do
      assert {:error, %DNSResolutionFailed{}} =
               TCP.connect("this.host.definitely.does.not.exist.invalid", 80, [])
    end

    test "returns error for connect timeout" do
      assert {:error, %Timeout{}} =
               TCP.connect("240.0.0.1", 80, connect_timeout: 100)
    end
  end

  describe "send/2 and recv/3" do
    test "round-trips data through echo server", %{port: port} do
      {:ok, transport} = TCP.connect("127.0.0.1", port, [])

      assert {:ok, transport} = TCP.send(transport, "hello")
      assert {:ok, _transport, "hello"} = TCP.recv(transport, 5, 5_000)
    end

    test "recv times out when no data available", %{port: port} do
      {:ok, transport} = TCP.connect("127.0.0.1", port, [])

      assert {:error, _transport, %Timeout{}} = TCP.recv(transport, 1, 100)
    end
  end

  describe "close/1" do
    test "closes the connection", %{port: port} do
      {:ok, transport} = TCP.connect("127.0.0.1", port, [])
      assert {:ok, %TCP{}} = TCP.close(transport)
    end
  end

  describe "activate/1" do
    test "receives data via process message after activation", %{port: port} do
      {:ok, transport} = TCP.connect("127.0.0.1", port, [])
      {:ok, transport} = TCP.send(transport, "active-test")
      {:ok, _transport} = TCP.activate(transport)

      assert_receive {:tcp, _socket, "active-test"}, 5_000
    end
  end

  describe "controlling_process/2" do
    test "transfers socket ownership", %{port: port} do
      {:ok, transport} = TCP.connect("127.0.0.1", port, [])

      test_pid = self()

      new_owner =
        spawn_link(fn ->
          receive do
            :go ->
              {:ok, transport} = TCP.send(transport, "from-new-owner")
              {:ok, _transport, data} = TCP.recv(transport, 0, 5_000)
              send(test_pid, {:received, data})
          end
        end)

      assert {:ok, _transport} = TCP.controlling_process(transport, new_owner)
      send(new_owner, :go)

      assert_receive {:received, "from-new-owner"}, 5_000
    end
  end
end
