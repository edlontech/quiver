defmodule Quiver.Transport.TCP do
  @moduledoc """
  TCP transport wrapping `:gen_tcp`.
  """

  @behaviour Quiver.Transport

  use TypedStruct

  alias Quiver.Error.ConnectionClosed
  alias Quiver.Error.ConnectionFailed
  alias Quiver.Error.ConnectionRefused
  alias Quiver.Error.DNSResolutionFailed
  alias Quiver.Error.Timeout

  typedstruct do
    field(:socket, :gen_tcp.socket(), enforce: true)
  end

  @impl true
  def connect(host, port, opts) do
    tcp_opts = [
      :binary,
      active: false,
      packet: :raw,
      buffer: Keyword.get(opts, :buffer_size, 8_192)
    ]

    host_charlist = to_charlist(host)
    timeout = Keyword.get(opts, :connect_timeout, 5_000)

    case :gen_tcp.connect(host_charlist, port, tcp_opts, timeout) do
      {:ok, socket} ->
        {:ok, %__MODULE__{socket: socket}}

      {:error, :econnrefused} ->
        {:error, ConnectionRefused.exception(message: "connection refused to #{host}:#{port}")}

      {:error, :nxdomain} ->
        {:error, DNSResolutionFailed.exception(host: host)}

      {:error, :timeout} ->
        {:error, Timeout.exception(message: "connect timeout to #{host}:#{port}")}

      {:error, reason} ->
        {:error,
         ConnectionFailed.exception(
           message: "failed to connect to #{host}:#{port}: #{inspect(reason)}"
         )}
    end
  end

  @impl true
  def send(%__MODULE__{socket: socket} = transport, data) do
    case :gen_tcp.send(socket, data) do
      :ok ->
        {:ok, transport}

      {:error, :closed} ->
        {:error, transport, ConnectionClosed.exception(message: "socket closed")}

      {:error, :timeout} ->
        {:error, transport, Timeout.exception(message: "send timeout")}

      {:error, reason} ->
        {:error, transport, reason}
    end
  end

  @impl true
  def recv(%__MODULE__{socket: socket} = transport, length, timeout) do
    case :gen_tcp.recv(socket, length, timeout) do
      {:ok, data} ->
        {:ok, transport, data}

      {:error, :closed} ->
        {:error, transport, ConnectionClosed.exception(message: "socket closed")}

      {:error, :timeout} ->
        {:error, transport, Timeout.exception(message: "recv timeout")}

      {:error, reason} ->
        {:error, transport, reason}
    end
  end

  @impl true
  def close(%__MODULE__{socket: socket} = transport) do
    :gen_tcp.close(socket)
    {:ok, transport}
  end

  @impl true
  def activate(%__MODULE__{socket: socket} = transport) do
    case :inet.setopts(socket, active: :once) do
      :ok -> {:ok, transport}
      {:error, reason} -> {:error, transport, reason}
    end
  end

  @impl true
  def controlling_process(%__MODULE__{socket: socket} = transport, pid) do
    case :gen_tcp.controlling_process(socket, pid) do
      :ok -> {:ok, transport}
      {:error, reason} -> {:error, transport, reason}
    end
  end
end
