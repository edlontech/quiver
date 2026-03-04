defmodule Quiver.Config.Rule do
  @moduledoc "A parsed pool routing rule with origin pattern and pool configuration."
  use TypedStruct

  typedstruct do
    field(:type, :exact | :wildcard | :default, enforce: true)
    field(:scheme, :https | :http)
    field(:host_pattern, [String.t() | :wildcard])
    field(:port, :inet.port_number())
    field(:config, keyword(), default: [])
  end
end

defmodule Quiver.Config do
  @moduledoc """
  Consolidated validation for all Quiver configuration.
  """

  alias Quiver.Config.Rule
  alias Quiver.Error.InvalidPoolOpts
  alias Quiver.Error.InvalidPoolRule

  @schema Zoi.keyword(
            size:
              Zoi.integer(description: "Number of connections in the pool.")
              |> Zoi.gte(1)
              |> Zoi.optional()
              |> Zoi.default(10),
            checkout_timeout:
              Zoi.integer(description: "Max wait time in ms to acquire a connection.")
              |> Zoi.gte(1)
              |> Zoi.optional()
              |> Zoi.default(5_000),
            idle_timeout:
              Zoi.integer(description: "Time in ms before idle connections are closed.")
              |> Zoi.gte(1)
              |> Zoi.optional()
              |> Zoi.default(30_000),
            ping_interval:
              Zoi.integer(description: "Interval in ms to check connection health.")
              |> Zoi.gte(1)
              |> Zoi.optional()
              |> Zoi.default(5_000),
            protocol:
              Zoi.enum([:auto, :http1, :http2],
                description: "HTTP protocol version. :auto detects via ALPN negotiation."
              )
              |> Zoi.optional()
              |> Zoi.default(:auto),
            max_connections:
              Zoi.integer(description: "Max HTTP/2 connections per origin.")
              |> Zoi.gte(1)
              |> Zoi.optional()
              |> Zoi.default(5),
            connect_timeout:
              Zoi.integer(description: "TCP/TLS connect timeout in ms.")
              |> Zoi.gte(1)
              |> Zoi.optional()
              |> Zoi.default(5_000),
            recv_timeout:
              Zoi.integer(description: "Socket receive timeout in ms.")
              |> Zoi.gte(1)
              |> Zoi.optional()
              |> Zoi.default(15_000),
            buffer_size:
              Zoi.integer(description: "Socket receive buffer size in bytes.")
              |> Zoi.gte(1)
              |> Zoi.optional()
              |> Zoi.default(8_192),
            verify:
              Zoi.enum([:verify_peer, :verify_none],
                description: "TLS certificate verification mode."
              )
              |> Zoi.optional()
              |> Zoi.default(:verify_peer),
            cacerts:
              Zoi.union([Zoi.literal(:default), Zoi.array(Zoi.any())],
                description: "CA certificates. :default uses OS store."
              )
              |> Zoi.optional()
              |> Zoi.default(:default),
            alpn_advertised_protocols:
              Zoi.array(Zoi.string(), description: "ALPN protocols to advertise during TLS.")
              |> Zoi.optional()
              |> Zoi.default([])
          )

  @doc false
  def schema, do: @schema

  @type pool_opts :: unquote(Zoi.type_spec(@schema))

  @doc """
  Validates pool and transport options against the unified schema, applying defaults.

  #{Zoi.describe(@schema)}
  """
  @spec validate_pool(pool_opts()) :: {:ok, pool_opts()} | {:error, InvalidPoolOpts.t()}
  def validate_pool(opts) do
    case Zoi.parse(@schema, opts) do
      {:ok, validated} -> {:ok, validated}
      {:error, errors} -> {:error, to_pool_error(errors)}
    end
  end

  # -- Pool Rules --

  @doc "Parses a pool configuration map into a specificity-sorted list of validated rules."
  @spec parse_rules(map()) ::
          {:ok, [Rule.t()]} | {:error, InvalidPoolRule.t() | InvalidPoolOpts.t()}
  def parse_rules(pools_map) when is_map(pools_map) do
    pools_map
    |> Enum.reduce_while([], fn {key, config}, acc ->
      case parse_rule(key, config) do
        {:ok, rule} -> {:cont, [rule | acc]}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:error, _} = error -> error
      rules -> {:ok, Enum.sort_by(rules, &rule_specificity/1, :desc)}
    end
  end

  @doc "Finds the first matching rule's config for the given origin, or nil."
  @spec resolve_config([Rule.t()], {atom(), String.t(), :inet.port_number()}) :: keyword() | nil
  def resolve_config(rules, {scheme, host, port}) do
    segments = String.split(host, ".")

    Enum.find_value(rules, fn rule ->
      if match_rule?(rule, scheme, segments, port), do: rule.config
    end)
  end

  # -- Rule Parsing --

  defp parse_rule(:default, config) do
    with {:ok, validated} <- validate_pool(config) do
      {:ok, %Rule{type: :default, config: validated}}
    end
  end

  defp parse_rule(key, config) when is_binary(key) do
    uri = URI.parse(key)

    with :ok <- validate_scheme(uri.scheme, key),
         {:ok, host_pattern, type} <- parse_host(uri.host, key),
         {:ok, validated} <- validate_pool(config) do
      port = uri.port || default_port(uri.scheme)

      {:ok,
       %Rule{
         type: type,
         scheme: scheme_to_atom(uri.scheme),
         host_pattern: host_pattern,
         port: port,
         config: validated
       }}
    end
  end

  defp parse_rule(key, _config) do
    {:error, InvalidPoolRule.exception(rule: key, reason: "key must be a URI string or :default")}
  end

  defp validate_scheme(scheme, _key) when scheme in ["http", "https"], do: :ok

  defp validate_scheme(nil, key) do
    {:error, InvalidPoolRule.exception(rule: key, reason: "missing scheme")}
  end

  defp validate_scheme(scheme, key) do
    {:error, InvalidPoolRule.exception(rule: key, reason: "unsupported scheme: #{scheme}")}
  end

  defp parse_host(nil, key) do
    {:error, InvalidPoolRule.exception(rule: key, reason: "missing host")}
  end

  defp parse_host(host, _key) do
    segments = String.split(host, ".")

    case segments do
      ["*" | rest] -> {:ok, [:wildcard | rest], :wildcard}
      _ -> {:ok, segments, :exact}
    end
  end

  defp default_port("https"), do: 443
  defp default_port("http"), do: 80

  defp scheme_to_atom("https"), do: :https
  defp scheme_to_atom("http"), do: :http

  # -- Rule Matching --

  defp rule_specificity(%Rule{type: :exact}), do: {2, 0}

  defp rule_specificity(%Rule{type: :wildcard, host_pattern: pattern}),
    do: {1, length(pattern) - 1}

  defp rule_specificity(%Rule{type: :default}), do: {0, 0}

  defp match_rule?(%Rule{type: :default}, _scheme, _segments, _port), do: true

  defp match_rule?(
         %Rule{type: :exact, scheme: rs, host_pattern: rp, port: rport},
         scheme,
         segments,
         port
       ) do
    rs == scheme and rp == segments and rport == port
  end

  defp match_rule?(
         %Rule{type: :wildcard, scheme: rs, host_pattern: [:wildcard | suffix], port: rport},
         scheme,
         segments,
         port
       ) do
    rs == scheme and rport == port and
      length(segments) == length(suffix) + 1 and
      tl(segments) == suffix
  end

  # -- Error Helpers --

  defp to_pool_error(errors) do
    messages = Enum.map(errors, & &1.message)
    InvalidPoolOpts.exception(errors: messages)
  end
end
