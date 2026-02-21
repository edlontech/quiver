defmodule Quiver.TestServer do
  @moduledoc false

  alias Quiver.Test.Certs

  def start(handler, opts \\ []) do
    {:ok, agent} = Agent.start(fn -> handler end)
    plug = {Quiver.TestServer.Plug, agent: agent}

    bandit_opts =
      [plug: plug, port: 0, ip: :loopback, startup_log: false]
      |> maybe_add_http2(opts)

    {certs, bandit_opts} = maybe_add_https(bandit_opts, opts)

    {:ok, pid} = Bandit.start_link(bandit_opts)
    Process.unlink(pid)
    {:ok, {_ip, port}} = ThousandIsland.listener_info(pid)

    result = %{port: port, server: pid, agent: agent}
    result = if certs, do: Map.put(result, :cacerts, certs.cacerts), else: result

    {:ok, result}
  end

  def start_raw(handler) do
    {:ok, listen_socket} =
      :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true, packet: :raw])

    {:ok, port} = :inet.port(listen_socket)
    pid = spawn_link(fn -> accept_loop_raw(listen_socket, handler) end)
    :ok = :gen_tcp.controlling_process(listen_socket, pid)

    {:ok, %{port: port, listen_socket: listen_socket}}
  end

  def stop(%{server: pid, agent: agent}) do
    GenServer.stop(pid)
    Agent.stop(agent)
  end

  def stop(%{listen_socket: socket}) do
    :gen_tcp.close(socket)
  end

  defp maybe_add_http2(opts, user_opts) do
    if user_opts[:http_2_only] do
      Keyword.merge(opts, http_1_options: [enabled: false])
    else
      opts
    end
  end

  defp maybe_add_https(opts, user_opts) do
    if user_opts[:https] do
      certs = Keyword.get(user_opts, :certs, Certs.generate("127.0.0.1"))

      bandit_opts =
        Keyword.merge(opts,
          scheme: :https,
          thousand_island_options: [
            transport_options: [
              cert: certs.cert,
              key: certs.key,
              cacerts: certs.cacerts
            ]
          ]
        )

      {certs, bandit_opts}
    else
      {nil, opts}
    end
  end

  defp accept_loop_raw(listen_socket, handler) do
    case :gen_tcp.accept(listen_socket, 1_000) do
      {:ok, socket} ->
        spawn_link(fn -> handle_raw_connection(socket, handler) end)
        accept_loop_raw(listen_socket, handler)

      {:error, :timeout} ->
        accept_loop_raw(listen_socket, handler)

      {:error, reason} when reason in [:closed, :einval] ->
        :ok
    end
  end

  defp handle_raw_connection(socket, handler) do
    {:ok, data} = :gen_tcp.recv(socket, 0, 5_000)
    raw_response = handler.(data)
    :gen_tcp.send(socket, raw_response)
    :gen_tcp.close(socket)
  rescue
    _ -> :gen_tcp.close(socket)
  end
end

defmodule Quiver.TestServer.Plug do
  @moduledoc false
  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    handler = Agent.get(opts[:agent], & &1)
    handler.(conn)
  end
end
