defmodule Quiver.Transport.SSLTest do
  use ExUnit.Case, async: true

  alias Quiver.Error.InvalidTransportOpts
  alias Quiver.Error.Timeout
  alias Quiver.Error.TLSHandshakeFailed
  alias Quiver.Error.TLSVerificationFailed
  alias Quiver.Test.Certs
  alias Quiver.Test.SSLListener
  alias Quiver.Transport.SSL

  setup_all do
    :ssl.start()
    certs = Certs.generate("localhost")
    %{certs: certs}
  end

  setup %{certs: certs} do
    {:ok, port, listen_socket} = SSLListener.start(certs)
    on_exit(fn -> SSLListener.stop(listen_socket) end)
    %{port: port, certs: certs}
  end

  describe "connect/3" do
    test "connects with valid cert and verify_peer", %{port: port, certs: certs} do
      opts = [verify: :verify_peer, cacerts: certs.cacerts]
      assert {:ok, %SSL{}} = SSL.connect("localhost", port, opts)
    end

    test "connects with verify_none", %{port: port} do
      assert {:ok, %SSL{}} = SSL.connect("localhost", port, verify: :verify_none)
    end

    test "fails with verify_peer and no matching CA", %{port: port} do
      assert {:error, error} = SSL.connect("localhost", port, verify: :verify_peer, cacerts: [])

      assert match?(%TLSVerificationFailed{}, error) or
               match?(%TLSHandshakeFailed{}, error)
    end

    test "validates options" do
      assert {:error, %InvalidTransportOpts{}} =
               SSL.connect("localhost", 443, connect_timeout: -1)
    end
  end

  describe "send/2 and recv/3" do
    test "round-trips data through SSL echo server", %{port: port} do
      {:ok, transport} = SSL.connect("localhost", port, verify: :verify_none)

      assert {:ok, transport} = SSL.send(transport, "hello-tls")
      assert {:ok, _transport, "hello-tls"} = SSL.recv(transport, 9, 5_000)
    end

    test "recv times out when no data available", %{port: port} do
      {:ok, transport} = SSL.connect("localhost", port, verify: :verify_none)
      assert {:error, _transport, %Timeout{}} = SSL.recv(transport, 1, 100)
    end
  end

  describe "close/1" do
    test "closes the connection", %{port: port} do
      {:ok, transport} = SSL.connect("localhost", port, verify: :verify_none)
      assert {:ok, %SSL{}} = SSL.close(transport)
    end
  end

  describe "activate/1" do
    test "receives data via process message", %{port: port} do
      {:ok, transport} = SSL.connect("localhost", port, verify: :verify_none)
      {:ok, transport} = SSL.send(transport, "active-ssl")
      {:ok, _transport} = SSL.activate(transport)

      assert_receive {:ssl, _socket, "active-ssl"}, 5_000
    end
  end

  describe "controlling_process/2" do
    test "transfers socket ownership to another process", %{port: port} do
      {:ok, transport} = SSL.connect("localhost", port, verify: :verify_none)

      test_pid = self()

      receiver =
        spawn(fn ->
          receive do
            :ready ->
              {:ok, transport} = SSL.send(transport, "owned")
              {:ok, _transport, data} = SSL.recv(transport, 5, 5_000)
              send(test_pid, {:received, data})
          end
        end)

      {:ok, _transport} = SSL.controlling_process(transport, receiver)
      send(receiver, :ready)

      assert_receive {:received, "owned"}, 5_000
    end
  end

  describe "negotiated_protocol/1" do
    test "returns nil when no ALPN negotiated", %{port: port} do
      {:ok, transport} = SSL.connect("localhost", port, verify: :verify_none)
      assert SSL.negotiated_protocol(transport) == nil
    end
  end
end
