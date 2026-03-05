defmodule Quiver.Transport.SSL do
  @moduledoc """
  SSL/TLS transport wrapping `:ssl`.

  Uses the OS certificate store via `:public_key.cacerts_get/0` and
  OTP's built-in hostname verification with wildcard SAN support.
  """

  @behaviour Quiver.Transport

  use TypedStruct

  alias Quiver.Error.ConnectionClosed
  alias Quiver.Error.ConnectionFailed
  alias Quiver.Error.ConnectionRefused
  alias Quiver.Error.DNSResolutionFailed
  alias Quiver.Error.Timeout
  alias Quiver.Error.TLSHandshakeFailed
  alias Quiver.Error.TLSVerificationFailed

  typedstruct do
    field(:socket, :ssl.sslsocket(), enforce: true)
    field(:negotiated_protocol, binary() | nil, default: nil)
  end

  @impl true
  def connect(host, port, opts) do
    ssl_opts =
      base_ssl_opts(host, opts)
      |> add_verification(to_charlist(host), opts)
      |> add_alpn(opts)

    Keyword.get(opts, :connect_timeout, 5_000)
    |> do_connect(to_charlist(host), port, ssl_opts)
    |> handle_connect_result(host, port)
  end

  @impl true
  def send(%__MODULE__{socket: socket} = transport, data) do
    case :ssl.send(socket, data) do
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
    case :ssl.recv(socket, length, timeout) do
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
    :ssl.close(socket)
    {:ok, transport}
  end

  @impl true
  def activate(%__MODULE__{socket: socket} = transport) do
    case :ssl.setopts(socket, active: :once) do
      :ok -> {:ok, transport}
      {:error, reason} -> {:error, transport, reason}
    end
  end

  @impl true
  def controlling_process(%__MODULE__{socket: socket} = transport, pid) do
    case :ssl.controlling_process(socket, pid) do
      :ok -> {:ok, transport}
      {:error, reason} -> {:error, transport, reason}
    end
  end

  @doc """
  Returns the ALPN protocol negotiated during the TLS handshake.

  Returns `nil` if no protocol was negotiated (e.g. no ALPN extension
  was advertised, or the server did not select one).
  """
  @spec negotiated_protocol(t()) :: binary() | nil
  def negotiated_protocol(%__MODULE__{negotiated_protocol: proto}), do: proto

  defp base_ssl_opts(host, opts) do
    [
      :binary,
      active: false,
      packet: :raw,
      buffer: Keyword.get(opts, :buffer_size, 8_192),
      server_name_indication: to_charlist(host)
    ]
  end

  defp do_connect(timeout, host_charlist, port, ssl_opts) do
    :ssl.connect(host_charlist, port, ssl_opts, timeout)
  end

  defp handle_connect_result({:ok, socket}, _host, _port) do
    protocol =
      case :ssl.negotiated_protocol(socket) do
        {:ok, proto} -> proto
        _ -> nil
      end

    {:ok, %__MODULE__{socket: socket, negotiated_protocol: protocol}}
  end

  defp handle_connect_result({:error, {:tls_alert, _} = reason}, host, _port) do
    classify_tls_error(host, reason)
  end

  defp handle_connect_result({:error, {:options, _} = reason}, _host, _port) do
    {:error, TLSHandshakeFailed.exception(reason: reason)}
  end

  defp handle_connect_result({:error, :timeout}, host, port) do
    {:error, Timeout.exception(message: "TLS connect timeout to #{host}:#{port}")}
  end

  defp handle_connect_result({:error, :nxdomain}, host, _port) do
    {:error, DNSResolutionFailed.exception(host: host)}
  end

  defp handle_connect_result({:error, :econnrefused}, host, port) do
    {:error, ConnectionRefused.exception(message: "connection refused to #{host}:#{port}")}
  end

  defp handle_connect_result({:error, reason}, host, port) do
    {:error,
     ConnectionFailed.exception(
       message: "TLS connect failed to #{host}:#{port}: #{inspect(reason)}"
     )}
  end

  defp add_verification(ssl_opts, _host_charlist, opts) do
    case Keyword.get(opts, :verify, :verify_peer) do
      :verify_peer ->
        cacerts = resolve_cacerts(Keyword.get(opts, :cacerts, :default))

        ssl_opts ++
          [
            verify: :verify_peer,
            cacerts: cacerts,
            customize_hostname_check: [match_fun: &wildcard_san_match/2],
            depth: 3
          ]

      :verify_none ->
        ssl_opts ++ [verify: :verify_none]
    end
  end

  defp wildcard_san_match({:dns_id, reference}, {:dNSName, [?*, ?. | presented]}) do
    case strip_first_label(reference) do
      [] -> :default
      domain -> :string.casefold(domain) == :string.casefold(presented)
    end
  end

  defp wildcard_san_match(_reference, _presented), do: :default

  defp strip_first_label([]), do: []
  defp strip_first_label([?. | domain]), do: domain
  defp strip_first_label([_ | rest]), do: strip_first_label(rest)

  defp add_alpn(ssl_opts, opts) do
    case Keyword.get(opts, :alpn_advertised_protocols, []) do
      [] -> ssl_opts
      protocols -> ssl_opts ++ [alpn_advertised_protocols: protocols]
    end
  end

  defp resolve_cacerts(:default), do: :public_key.cacerts_get()
  defp resolve_cacerts(certs) when is_list(certs), do: certs

  defp classify_tls_error(host, {:tls_alert, {alert_type, _}})
       when alert_type in [
              :bad_certificate,
              :certificate_expired,
              :certificate_revoked,
              :certificate_unknown,
              :unknown_ca
            ] do
    {:error, TLSVerificationFailed.exception(host: host)}
  end

  defp classify_tls_error(_host, reason) do
    {:error, TLSHandshakeFailed.exception(reason: reason)}
  end
end
