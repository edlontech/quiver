defmodule Quiver.Pool.Registration do
  @moduledoc """
  Process-name registration helper used by pool modules to close the
  race between `:persistent_term` publication and Registry visibility.

  Pool processes publish a per-pid `:persistent_term` marker that
  `Quiver.Pool.Manager` and `Quiver.detect_pool_module/1` rely on to
  classify a pool by protocol. If the pool's `:via` name registration
  happens before the persistent_term is written (which is the default
  for `:gen_statem.start_link/3` when `name:` is passed), a concurrent
  caller can find the pid via `Registry.lookup/2` while
  `detect_pool_module/1` still sees no marker and falls through to the
  default classification, dispatching the wrong protocol module on the
  pid.

  Callers register the name themselves AFTER publishing the
  persistent_term marker, so that a pid is only ever observable through
  the Registry once the marker is in place.
  """

  @type name :: nil | {:via, module(), term()} | atom()

  @doc """
  Registers `pid` under `name`. Supported name shapes mirror what OTP
  accepts for `gen_*` `name:` options:

    * `nil` — no-op (the process stays anonymous).
    * `{:via, Mod, args}` — calls `Mod.register_name(args, pid)`.
    * atom — local registration via `Process.register/2`.

  Returns `:ok` on success, or `{:error, {:already_started, existing_pid}}`
  if another process owns the name.
  """
  @spec register(pid(), name()) :: :ok | {:error, {:already_started, pid()}}
  def register(_pid, nil), do: :ok

  def register(pid, {:via, mod, args}) when is_atom(mod) do
    case mod.register_name(args, pid) do
      :yes ->
        :ok

      :no ->
        case mod.whereis_name(args) do
          existing when is_pid(existing) and existing != pid ->
            {:error, {:already_started, existing}}

          _ ->
            {:error, {:already_started, pid}}
        end
    end
  end

  def register(pid, name) when is_atom(name) do
    Process.register(pid, name)
    :ok
  rescue
    ArgumentError ->
      case Process.whereis(name) do
        existing when is_pid(existing) and existing != pid ->
          {:error, {:already_started, existing}}

        _ ->
          {:error, {:already_started, pid}}
      end
  end
end
