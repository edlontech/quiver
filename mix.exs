defmodule Quiver.MixProject do
  use Mix.Project

  def project do
    [
      app: :quiver,
      description: description(),
      package: package(),
      version: "0.1.0",
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [
        plt_core_path: "_plts/core"
      ],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.cobertura": :test
      ],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "bench/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:assert_eventually, "~> 1.0", only: :test},
      {:bandit, "~> 1.0", only: [:dev, :test]},
      {:benchee, "~> 1.0", only: :dev},
      {:benchee_html, "~> 1.0", only: :dev},
      {:benchee_json, "~> 1.0", only: :dev},
      {:finch, "~> 0.19", only: :dev},
      {:castore, "~> 1.0"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.22", only: :dev},
      {:ex_check, "~> 0.16", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: [:dev, :test]},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:gen_state_machine, "~> 3.0"},
      {:hpax, "~> 1.0"},
      {:mimic, "~> 2.2", only: :test},
      {:mix_audit, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:nimble_pool, "~> 1.1"},
      {:recode, "~> 0.8", only: [:dev], runtime: false},
      {:splode, "~> 0.2"},
      {:ssl_verify_fun, "~> 1.1"},
      {:telemetry, "~> 1.0"},
      {:testcontainers, "~> 1.13", only: [:test, :dev]},
      {:typedstruct, "~> 0.5"},
      {:zoi, "~> 0.11"}
    ]
  end

  defp aliases do
    [
      test: ["test --exclude integration"],
      "test.integration": ["test --only integration"],
      "bench.concurrency": ["run bench/concurrency.exs"],
      "bench.payload": ["run bench/payload.exs"],
      "bench.pool_pressure": ["run bench/pool_pressure.exs"],
      "bench.profile_payload": ["run bench/profile_payload.exs"],
      "bench.streaming": ["run bench/streaming.exs"],
      "bench.vs_finch": ["run bench/vs_finch.exs"],
      "bench.all": [
        "bench.concurrency",
        "bench.payload",
        "bench.pool_pressure",
        "bench.profile_payload",
        "bench.streaming",
        "bench.vs_finch"
      ]
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.post": :test,
        "coveralls.github": :test,
        "coveralls.html": :test,
        "test.integration": :test
      ]
    ]
  end

  defp description() do
    "A blazing fast, resilient, and easy-to-use HTTP client for Elixir"
  end

  defp package() do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/edlontech/quiver.git"}
    ]
  end
end
