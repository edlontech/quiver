defmodule Quiver.Pool.Manager do
  @moduledoc """
  Stateless pool routing module.

  Looks up existing pools via Registry (hot path) and creates new ones
  via DynamicSupervisor on first request to an origin (cold path).
  """

  alias Quiver.Config
  alias Quiver.Error.PoolStartFailed
  alias Quiver.Pool.HTTP1
  alias Quiver.Pool.HTTP2
  alias Quiver.Transport

  @type origin :: {:http | :https, String.t(), :inet.port_number()}

  @doc "Returns an existing pool for the origin, or starts one via DynamicSupervisor."
  @spec get_pool(atom(), origin()) :: {:ok, pid()} | {:error, term()}
  def get_pool(name, origin) do
    registry = Quiver.Supervisor.registry_name(name)

    case Registry.lookup(registry, origin) do
      [{pid, _}] -> {:ok, pid}
      [] -> start_pool(name, origin)
    end
  end

  @doc "Returns pool stats for a known origin, or `{:error, :not_found}`."
  @spec pool_stats(atom(), origin()) :: {:ok, map()} | {:error, :not_found}
  def pool_stats(name, origin) do
    registry = Quiver.Supervisor.registry_name(name)

    case Registry.lookup(registry, origin) do
      [{pid, _}] -> {:ok, fetch_stats(pid)}
      [] -> {:error, :not_found}
    end
  end

  defp fetch_stats(pid) do
    cond do
      :persistent_term.get({HTTP1, pid}, nil) -> HTTP1.stats(pid)
      :persistent_term.get({HTTP2, pid}, nil) -> HTTP2.stats(pid)
      true -> %{active: 0, idle: 0, queued: 0, connections: 0}
    end
  end

  defp start_pool(name, origin) do
    rules = :persistent_term.get({__MODULE__, name, :rules})
    config = Config.resolve_config(rules, origin) || []
    pool_module = pool_module_for(config, origin)
    registry = Quiver.Supervisor.registry_name(name)
    supervisor = Quiver.Supervisor.supervisor_name(name)

    spec =
      {pool_module, origin: origin, pool_opts: config, name: {:via, Registry, {registry, origin}}}

    case DynamicSupervisor.start_child(supervisor, spec) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, reason} -> {:error, PoolStartFailed.exception(origin: origin, reason: reason)}
    end
  end

  defp pool_module_for(config, origin) do
    case Keyword.get(config, :protocol, :auto) do
      :http2 -> HTTP2
      :http1 -> HTTP1
      :auto -> detect_protocol(config, origin)
    end
  end

  defp detect_protocol(config, {:https, host, port}) do
    ssl_opts =
      Keyword.take(config, [:connect_timeout, :verify, :cacerts, :buffer_size])
      |> Keyword.put(:alpn_advertised_protocols, ["h2", "http/1.1"])

    case Transport.SSL.connect(host, port, ssl_opts) do
      {:ok, transport} ->
        proto = Transport.SSL.negotiated_protocol(transport)
        Transport.SSL.close(transport)
        if proto == "h2", do: HTTP2, else: HTTP1

      {:error, _} ->
        HTTP1
    end
  end

  defp detect_protocol(_config, _origin), do: HTTP1
end
