defmodule Quiver.H3TestServer do
  @moduledoc false

  alias Quiver.Test.Certs

  @type t :: %{name: atom(), port: pos_integer(), cacerts: [binary()]}

  @doc """
  Starts a one-off HTTP/3 server bound to an ephemeral port. Returns
  `{:ok, %{name: atom, port: integer, cacerts: [der]}}`.

  `handler` is a 5-arity fun `(conn, stream_id, method, path, headers) -> any`
  invoked by `:quic_h3` per request. The `conn` argument is the HTTP/3
  connection pid; use it (not `self()`) for `:quic_h3.send_response/4`
  and `:quic_h3.send_data/4`.
  """
  @spec start(fun()) :: {:ok, t()}
  def start(handler) do
    name = :"h3_test_server_#{System.unique_integer([:positive])}"
    certs = Certs.generate("localhost")

    {:ok, _pid} =
      :quic_h3.start_server(name, 0, %{
        cert: certs.cert,
        key: decode_key(certs.key),
        handler: handler,
        alpn: [<<"h3">>]
      })

    {:ok, port} = :quic.get_server_port(name)
    {:ok, %{name: name, port: port, cacerts: certs.cacerts}}
  end

  defp decode_key({:RSAPrivateKey, der}) when is_binary(der) do
    :public_key.der_decode(:RSAPrivateKey, der)
  end

  defp decode_key({:ECPrivateKey, der}) when is_binary(der) do
    :public_key.der_decode(:ECPrivateKey, der)
  end

  defp decode_key(other), do: other

  @doc "Stops a server previously started with `start/1`."
  @spec stop(atom()) :: :ok | {:error, term()}
  def stop(name), do: :quic_h3.stop_server(name)
end
