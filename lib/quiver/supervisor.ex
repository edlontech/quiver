defmodule Quiver.Supervisor.Cleanup do
  @moduledoc false
  use GenServer

  @doc false
  def start_link(name), do: GenServer.start_link(__MODULE__, name)

  @impl true
  def init(name) do
    Process.flag(:trap_exit, true)
    {:ok, name}
  end

  @impl true
  def terminate(_reason, name) do
    :persistent_term.erase({Quiver.Pool.Manager, name, :rules})
    :ok
  end
end

defmodule Quiver.Supervisor do
  @moduledoc """
  Named supervision tree for a Quiver HTTP client instance.

  Starts a Registry for pool lookup and a DynamicSupervisor for pool processes.
  Pool config rules are parsed eagerly and stored in `:persistent_term`.

  The `name` option must be a compile-time atom. Dynamic atom creation
  from user input will exhaust the atom table.

  ## Usage

      children = [
        {Quiver.Supervisor, name: :my_client, pools: %{:default => [size: 5]}}
      ]

  """

  use Supervisor

  alias Quiver.Config

  @doc "Starts a named Quiver instance with the given pool configuration."
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    name = Keyword.fetch!(opts, :name)
    pools_config = Keyword.get(opts, :pools, %{:default => []})

    case Config.parse_rules(pools_config) do
      {:error, error} -> raise error
      {:ok, rules} -> :persistent_term.put({Quiver.Pool.Manager, name, :rules}, rules)
    end

    children = [
      {Quiver.Supervisor.Cleanup, name},
      {Registry, keys: :unique, name: registry_name(name)},
      {DynamicSupervisor, name: supervisor_name(name), strategy: :one_for_one}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  @doc "Derives the Registry name for a Quiver instance."
  @spec registry_name(atom()) :: atom()
  def registry_name(name) when is_atom(name), do: :"#{name}.Registry"

  @doc "Derives the DynamicSupervisor name for a Quiver instance."
  @spec supervisor_name(atom()) :: atom()
  def supervisor_name(name) when is_atom(name), do: :"#{name}.PoolSupervisor"
end
