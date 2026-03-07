defmodule Quiver.ConfigTest do
  use ExUnit.Case, async: true

  alias Quiver.Config
  alias Quiver.Config.Rule
  alias Quiver.Error.InvalidPoolOpts
  alias Quiver.Error.InvalidPoolRule

  describe "validate_pool/1" do
    test "returns defaults when given empty list" do
      assert {:ok, validated} = Config.validate_pool([])
      assert validated[:size] == 10
      assert validated[:checkout_timeout] == 5_000
      assert validated[:idle_timeout] == 30_000
      assert validated[:ping_interval] == 5_000
      assert validated[:connect_timeout] == 5_000
      assert validated[:recv_timeout] == 15_000
      assert validated[:buffer_size] == 8_192
      assert validated[:verify] == :verify_peer
      assert validated[:cacerts] == :default
      assert validated[:alpn_advertised_protocols] == []
    end

    test "accepts valid overrides" do
      assert {:ok, validated} = Config.validate_pool(size: 25, checkout_timeout: 10_000)
      assert validated[:size] == 25
      assert validated[:checkout_timeout] == 10_000
      assert validated[:idle_timeout] == 30_000
    end

    test "rejects non-positive size" do
      assert {:error, %InvalidPoolOpts{}} = Config.validate_pool(size: 0)
    end

    test "rejects non-positive checkout_timeout" do
      assert {:error, %InvalidPoolOpts{}} = Config.validate_pool(checkout_timeout: -1)
    end

    test "rejects non-positive idle_timeout" do
      assert {:error, %InvalidPoolOpts{}} = Config.validate_pool(idle_timeout: 0)
    end

    test "rejects non-positive ping_interval" do
      assert {:error, %InvalidPoolOpts{}} = Config.validate_pool(ping_interval: 0)
    end

    test "accepts protocol :http2" do
      assert {:ok, config} = Config.validate_pool(protocol: :http2)
      assert config[:protocol] == :http2
    end

    test "accepts protocol :http1" do
      assert {:ok, config} = Config.validate_pool(protocol: :http1)
      assert config[:protocol] == :http1
    end

    test "accepts protocol :auto" do
      assert {:ok, config} = Config.validate_pool(protocol: :auto)
      assert config[:protocol] == :auto
    end

    test "defaults protocol to :auto" do
      assert {:ok, config} = Config.validate_pool([])
      assert config[:protocol] == :auto
    end

    test "rejects invalid protocol" do
      assert {:error, %InvalidPoolOpts{}} = Config.validate_pool(protocol: :http3)
    end

    test "defaults max_connections to 1" do
      assert {:ok, config} = Config.validate_pool([])
      assert config[:max_connections] == 1
    end

    test "accepts valid max_connections" do
      assert {:ok, config} = Config.validate_pool(max_connections: 10)
      assert config[:max_connections] == 10
    end

    test "rejects non-positive max_connections" do
      assert {:error, %InvalidPoolOpts{}} = Config.validate_pool(max_connections: 0)
    end

    test "accepts valid transport options" do
      assert {:ok, opts} =
               Config.validate_pool(
                 connect_timeout: 10_000,
                 recv_timeout: 30_000,
                 buffer_size: 16_384
               )

      assert opts[:connect_timeout] == 10_000
      assert opts[:recv_timeout] == 30_000
      assert opts[:buffer_size] == 16_384
    end

    test "rejects non-positive connect_timeout" do
      assert {:error, %InvalidPoolOpts{}} = Config.validate_pool(connect_timeout: 0)
    end

    test "rejects non-integer connect_timeout" do
      assert {:error, %InvalidPoolOpts{}} = Config.validate_pool(connect_timeout: "fast")
    end

    test "rejects non-positive recv_timeout" do
      assert {:error, %InvalidPoolOpts{}} = Config.validate_pool(recv_timeout: -1)
    end

    test "rejects non-positive buffer_size" do
      assert {:error, %InvalidPoolOpts{}} = Config.validate_pool(buffer_size: 0)
    end

    test "accepts verify: :verify_none" do
      assert {:ok, opts} = Config.validate_pool(verify: :verify_none)
      assert opts[:verify] == :verify_none
    end

    test "accepts verify: :verify_peer" do
      assert {:ok, opts} = Config.validate_pool(verify: :verify_peer)
      assert opts[:verify] == :verify_peer
    end

    test "rejects invalid verify value" do
      assert {:error, %InvalidPoolOpts{}} = Config.validate_pool(verify: :yolo)
    end

    test "accepts cacerts: :default" do
      assert {:ok, opts} = Config.validate_pool(cacerts: :default)
      assert opts[:cacerts] == :default
    end

    test "accepts proxy config with host and port" do
      assert {:ok, opts} =
               Config.validate_pool(proxy: [host: "proxy.example.com", port: 8080])

      assert opts[:proxy][:host] == "proxy.example.com"
      assert opts[:proxy][:port] == 8080
      assert opts[:proxy][:scheme] == :http
      assert opts[:proxy][:headers] == []
    end

    test "accepts proxy config with all options" do
      assert {:ok, opts} =
               Config.validate_pool(
                 proxy: [
                   host: "proxy.example.com",
                   port: 3128,
                   scheme: :https,
                   headers: [{"proxy-authorization", "Basic abc"}]
                 ]
               )

      assert opts[:proxy][:scheme] == :https
      assert opts[:proxy][:headers] == [{"proxy-authorization", "Basic abc"}]
    end

    test "defaults proxy to nil when not provided" do
      assert {:ok, opts} = Config.validate_pool([])
      assert opts[:proxy] == nil
    end

    test "rejects proxy with missing host" do
      assert {:error, %InvalidPoolOpts{}} = Config.validate_pool(proxy: [port: 8080])
    end

    test "rejects proxy with missing port" do
      assert {:error, %InvalidPoolOpts{}} =
               Config.validate_pool(proxy: [host: "proxy.example.com"])
    end

    test "rejects proxy with port out of range" do
      assert {:error, %InvalidPoolOpts{}} =
               Config.validate_pool(proxy: [host: "proxy.example.com", port: 70_000])
    end

    test "rejects proxy with invalid scheme" do
      assert {:error, %InvalidPoolOpts{}} =
               Config.validate_pool(proxy: [host: "proxy.example.com", port: 8080, scheme: :ftp])
    end
  end

  describe "parse_rules/1" do
    test "parses exact origin" do
      assert {:ok,
              [
                %Rule{
                  type: :exact,
                  scheme: :https,
                  host_pattern: ["api", "example", "com"],
                  port: 443
                }
              ]} =
               Config.parse_rules(%{"https://api.example.com" => [size: 25]})
    end

    test "parses wildcard origin" do
      assert {:ok,
              [
                %Rule{
                  type: :wildcard,
                  scheme: :https,
                  host_pattern: [:wildcard, "example", "com"],
                  port: 443
                }
              ]} =
               Config.parse_rules(%{"https://*.example.com" => [size: 10]})
    end

    test "parses default" do
      assert {:ok, [%Rule{type: :default}]} = Config.parse_rules(%{default: [size: 5]})
    end

    test "sorts by specificity: exact > wildcard > default" do
      {:ok, rules} =
        Config.parse_rules(%{
          :default => [size: 5],
          "https://api.example.com" => [size: 25],
          "https://*.example.com" => [size: 10]
        })

      types = Enum.map(rules, & &1.type)
      assert types == [:exact, :wildcard, :default]
    end

    test "more specific wildcards come first" do
      {:ok, [first, second]} =
        Config.parse_rules(%{
          "https://*.example.com" => [size: 10],
          "https://*.cdn.example.com" => [size: 50]
        })

      assert first.host_pattern == [:wildcard, "cdn", "example", "com"]
      assert second.host_pattern == [:wildcard, "example", "com"]
    end

    test "infers port 443 for https and 80 for http" do
      {:ok, rules} =
        Config.parse_rules(%{
          "https://a.com" => [],
          "http://b.com" => []
        })

      https_rule = Enum.find(rules, &(&1.host_pattern == ["a", "com"]))
      http_rule = Enum.find(rules, &(&1.host_pattern == ["b", "com"]))
      assert https_rule.port == 443
      assert http_rule.port == 80
    end

    test "uses explicit port when provided" do
      assert {:ok, [%Rule{port: 8443}]} =
               Config.parse_rules(%{"https://api.example.com:8443" => [size: 5]})
    end

    test "returns error for invalid URI" do
      assert {:error, %InvalidPoolRule{}} = Config.parse_rules(%{"not a url" => []})
    end

    test "returns error for unsupported scheme" do
      assert {:error, %InvalidPoolRule{}} = Config.parse_rules(%{"ftp://host.com" => []})
    end

    test "returns error for non-string, non-default key" do
      assert {:error, %InvalidPoolRule{}} = Config.parse_rules(%{123 => []})
    end

    test "returns empty list for empty map" do
      assert {:ok, []} = Config.parse_rules(%{})
    end

    test "returns error for invalid pool config" do
      assert {:error, %InvalidPoolOpts{}} =
               Config.parse_rules(%{"https://api.example.com" => [size: -1]})
    end

    test "validates default pool config eagerly" do
      assert {:error, %InvalidPoolOpts{}} =
               Config.parse_rules(%{:default => [checkout_timeout: 0]})
    end
  end

  describe "resolve_config/2" do
    setup do
      {:ok, rules} =
        Config.parse_rules(%{
          "https://api.example.com" => [size: 25],
          "https://*.cdn.example.com" => [size: 50],
          "https://*.example.com" => [size: 10],
          :default => [size: 5]
        })

      %{rules: rules}
    end

    test "exact match wins", %{rules: rules} do
      config = Config.resolve_config(rules, {:https, "api.example.com", 443})
      assert config[:size] == 25
    end

    test "specific wildcard beats broad wildcard", %{rules: rules} do
      config = Config.resolve_config(rules, {:https, "us.cdn.example.com", 443})
      assert config[:size] == 50
    end

    test "broad wildcard matches when specific does not", %{rules: rules} do
      config = Config.resolve_config(rules, {:https, "other.example.com", 443})
      assert config[:size] == 10
    end

    test "default when nothing else matches", %{rules: rules} do
      config = Config.resolve_config(rules, {:https, "totally-different.com", 443})
      assert config[:size] == 5
    end

    test "wildcard does NOT match deeper subdomains", %{rules: rules} do
      config = Config.resolve_config(rules, {:https, "a.b.example.com", 443})
      assert config[:size] == 5
    end

    test "scheme mismatch falls through to default", %{rules: rules} do
      config = Config.resolve_config(rules, {:http, "api.example.com", 80})
      assert config[:size] == 5
    end

    test "port mismatch falls through to default", %{rules: rules} do
      config = Config.resolve_config(rules, {:https, "api.example.com", 8443})
      assert config[:size] == 5
    end

    test "returns nil when no rules and no default" do
      {:ok, rules} = Config.parse_rules(%{"https://api.example.com" => [size: 25]})
      assert nil == Config.resolve_config(rules, {:https, "other.com", 443})
    end
  end
end
