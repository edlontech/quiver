defmodule Quiver.Pool.HTTP3.EarlyData do
  @moduledoc false
  # Pure 0-RTT eligibility policy. RFC 9001 §9.2: only replay-safe requests
  # ride early by default; an explicit per-request opt forces or suppresses.

  @safe_methods [:get, :head, :options, :trace]

  @doc false
  @spec enabled?(keyword()) :: boolean()
  def enabled?(config), do: Keyword.get(config, :early_data, false) == true

  @doc false
  @spec eligible?(atom(), keyword(), keyword()) :: boolean()
  def eligible?(method, opts, config) do
    cond do
      not enabled?(config) -> false
      Keyword.get(opts, :early_data) == false -> false
      Keyword.get(opts, :early_data) == true -> true
      true -> method in @safe_methods
    end
  end
end
