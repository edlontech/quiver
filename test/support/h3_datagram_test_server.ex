defmodule Quiver.Test.H3DatagramTestServer do
  @moduledoc """
  Test fixture wrapping `:quic_h3.start_server/3` with datagram support.

  Spawns a per-server owner process that handles incoming
  `{:quic_h3, conn, {:datagram, sid, payload}}` events according to each
  route's configured behaviour (echo, sidechannel, etc.).

  Routes:

  - `/echo` -- 200 OK, echo every datagram back to the sender
  - `/reject` -- 403 + END_STREAM (used with extended CONNECT)
  - `/pre-response-datagram` -- send a datagram BEFORE the 200 OK headers
  - `/sidechannel` -- 200 OK with a tiny body (buffered request route that
     also receives datagrams, used for the `:dropped` telemetry test)
  - `/no-datagrams` -- start with `start_no_datagrams/2` (datagram
     negotiation off)
  - `/slow` -- never send a response (for timeout tests)
  - `/big` -- 200 OK, accept any datagram size

  Returns `{:ok, %{name, port, cacerts, owner}}`. `cacerts` are needed if
  the client uses `verify: :verify_peer`; tests typically run with
  `verify: :verify_none`.
  """

  alias Quiver.Test.Certs

  @type t :: %{name: atom(), port: pos_integer(), cacerts: [binary()], owner: pid()}

  @doc """
  Starts a datagram-enabled HTTP/3 test server.

  Options:
    * `:h3_datagram_enabled` (default `true`) -- flip to `false` to simulate
      a peer that did not negotiate RFC 9297.
    * `:goaway_on_open` (default `false`) -- when `true`, the owner sends
      `:quic_h3.goaway/1` immediately after the first response is sent.
      Used to drive the GOAWAY integration test.
    * `:listener` (default `nil`) -- when set, every incoming request causes
      the owner to forward `{:request_headers, path, method, headers}` to
      this pid. Used by Task 5's extended CONNECT test to assert on
      pseudo-header ordering.
  """
  @spec start(atom(), keyword()) :: {:ok, t()}
  def start(name_prefix \\ :h3_dg_srv, opts \\ []) do
    name = :"#{name_prefix}_#{System.unique_integer([:positive])}"
    certs = Certs.generate("localhost")
    h3_datagram_enabled = Keyword.get(opts, :h3_datagram_enabled, true)
    goaway_on_open = Keyword.get(opts, :goaway_on_open, false)
    listener = Keyword.get(opts, :listener)
    enable_connect_protocol = Keyword.get(opts, :enable_connect_protocol, false)

    owner =
      spawn_link(fn ->
        owner_loop(%{datagrams: %{}, goaway_on_open: goaway_on_open, listener: listener})
      end)

    server_opts =
      %{
        cert: certs.cert,
        key: decode_key(certs.key),
        alpn: [<<"h3">>],
        h3_datagram_enabled: h3_datagram_enabled,
        connection_handler: fn _conn -> %{owner: owner} end,
        handler: build_handler(owner)
      }
      |> maybe_put_connect_protocol(enable_connect_protocol)

    {:ok, _pid} = :quic_h3.start_server(name, 0, server_opts)

    {:ok, port} = :quic.get_server_port(name)
    {:ok, %{name: name, port: port, cacerts: certs.cacerts, owner: owner}}
  end

  @doc "Convenience: server with `h3_datagram_enabled: false`."
  @spec start_no_datagrams(atom(), keyword()) :: {:ok, t()}
  def start_no_datagrams(name_prefix \\ :h3_no_dg_srv, opts \\ []) do
    start(name_prefix, Keyword.put(opts, :h3_datagram_enabled, false))
  end

  @doc "Stops a server started with `start/2`."
  @spec stop(t()) :: :ok | {:error, term()}
  def stop(%{name: name, owner: owner}) do
    if Process.alive?(owner), do: Process.exit(owner, :shutdown)
    :quic_h3.stop_server(name)
  end

  # -- internals --

  defp maybe_put_connect_protocol(opts, false), do: opts

  defp maybe_put_connect_protocol(opts, true) do
    Map.put(opts, :settings, %{enable_connect_protocol: 1})
  end

  defp build_handler(owner) do
    fn h3_conn, sid, method, path, headers ->
      send(owner, {:request_headers, path, method, headers})
      handle_route(owner, h3_conn, sid, path)
    end
  end

  defp handle_route(owner, h3_conn, sid, "/echo") do
    send(owner, {:register_stream, h3_conn, sid, :echo})
    :quic_h3.send_response(h3_conn, sid, 200, [])
    :ok
  end

  defp handle_route(_owner, h3_conn, sid, "/reject") do
    :quic_h3.send_response(h3_conn, sid, 403, [])
    :quic_h3.send_data(h3_conn, sid, <<>>, true)
  end

  defp handle_route(_owner, h3_conn, sid, "/pre-response-datagram") do
    :quic_h3.send_datagram(h3_conn, sid, "early")
    Process.sleep(50)
    :quic_h3.send_response(h3_conn, sid, 200, [])
    Process.sleep(50)
    :quic_h3.send_data(h3_conn, sid, <<>>, true)
  end

  defp handle_route(owner, h3_conn, sid, "/sidechannel") do
    send(owner, {:register_stream, h3_conn, sid, :sidechannel})
    :quic_h3.send_response(h3_conn, sid, 200, [])
    :quic_h3.send_datagram(h3_conn, sid, "side")
    Process.sleep(50)
    :quic_h3.send_data(h3_conn, sid, "body", true)
  end

  defp handle_route(_owner, _h3_conn, _sid, "/slow"), do: :ok

  defp handle_route(owner, h3_conn, sid, "/big") do
    send(owner, {:register_stream, h3_conn, sid, :echo})
    :quic_h3.send_response(h3_conn, sid, 200, [])
    :ok
  end

  defp handle_route(owner, h3_conn, sid, "/extended-connect") do
    send(owner, {:register_stream, h3_conn, sid, :echo})
    :quic_h3.send_response(h3_conn, sid, 200, [])
    :ok
  end

  defp handle_route(_owner, h3_conn, sid, _path) do
    :quic_h3.send_response(h3_conn, sid, 404, [])
    :quic_h3.send_data(h3_conn, sid, <<>>, true)
  end

  defp owner_loop(state) do
    receive do
      {:register_stream, h3_conn, sid, mode} ->
        state = put_in(state, [:datagrams, {h3_conn, sid}], mode)

        if state.goaway_on_open do
          :quic_h3.goaway(h3_conn)
        end

        owner_loop(state)

      {:request_headers, _path, _method, _headers} = msg ->
        if is_pid(state.listener) and Process.alive?(state.listener) do
          send(state.listener, msg)
        end

        owner_loop(state)

      {:quic_h3, h3_conn, {:datagram, sid, payload}} ->
        case Map.get(state.datagrams, {h3_conn, sid}) do
          :echo -> :quic_h3.send_datagram(h3_conn, sid, payload)
          _ -> :ok
        end

        owner_loop(state)

      {:quic_h3, _conn, _other} ->
        owner_loop(state)

      _other ->
        owner_loop(state)
    end
  end

  defp decode_key({:RSAPrivateKey, der}) when is_binary(der) do
    :public_key.der_decode(:RSAPrivateKey, der)
  end

  defp decode_key({:ECPrivateKey, der}) when is_binary(der) do
    :public_key.der_decode(:ECPrivateKey, der)
  end

  defp decode_key(other), do: other
end
