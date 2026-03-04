defmodule Quiver do
  @moduledoc """
  A mid-level HTTP client for Elixir supporting HTTP/1.1, HTTP/2, and HTTP/3.

  ## Usage

      # Using the default supervisor name (Quiver.Pool):
      children = [{Quiver.Supervisor, pools: %{default: []}}]

      {:ok, %Quiver.Response{status: 200, body: body}} =
        Quiver.new(:get, "https://example.com/api")
        |> Quiver.header("authorization", "Bearer token")
        |> Quiver.request()

      # Using a custom supervisor name:
      children = [{Quiver.Supervisor, name: :my_client, pools: %{default: []}}]

      {:ok, %Quiver.Response{status: 200, body: body}} =
        Quiver.new(:get, "https://example.com/api")
        |> Quiver.request(name: :my_client)
  """

  alias Quiver.Pool.HTTP1, as: PoolHTTP1
  alias Quiver.Pool.HTTP2, as: PoolHTTP2
  alias Quiver.Pool.Manager
  alias Quiver.Request
  alias Quiver.Response
  alias Quiver.StreamResponse
  alias Quiver.Telemetry

  @default_name Quiver.Pool
  @default_receive_timeout 15_000

  @doc "Returns the default supervisor name (`Quiver.Pool`)."
  @spec default_name() :: atom()
  def default_name, do: @default_name

  @spec new(Quiver.Conn.method(), String.t()) :: Request.t()
  def new(method, url) when is_atom(method) and is_binary(url) do
    %Request{method: method, url: URI.parse(url)}
  end

  @spec header(Request.t(), String.t(), String.t()) :: Request.t()
  def header(%Request{} = request, key, value)
      when is_binary(key) and is_binary(value) do
    %{request | headers: request.headers ++ [{key, value}]}
  end

  @spec body(Request.t(), iodata()) :: Request.t()
  def body(%Request{} = request, body) do
    %{request | body: body}
  end

  @doc """
  Executes the request and returns the full response.

  ## Options

  - `:name` -- atom identifying the `Quiver.Supervisor` (default: `Quiver.Pool`)
  - `:receive_timeout` -- max ms to wait per response chunk (default: 15,000)
  """
  @spec request(Request.t(), keyword()) :: {:ok, Response.t()} | {:error, term()}
  def request(%Request{} = request, opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, @default_name)
    timeout = Keyword.get(opts, :receive_timeout, @default_receive_timeout)

    do_request(request, name, fn pool ->
      pool_mod = detect_pool_module(pool)

      pool_mod.request(
        pool,
        request.method,
        build_path(request.url),
        request.headers,
        request.body,
        timeout: timeout
      )
    end)
  end

  @doc """
  Executes the request in streaming mode.

  Returns a `StreamResponse` with eagerly-received status and headers,
  and a lazy body stream of binary chunks.

  ## Options

  - `:name` -- atom identifying the `Quiver.Supervisor` (default: `Quiver.Pool`)
  - `:receive_timeout` -- max ms to wait per response chunk (default: 15,000)
  """
  @spec stream_request(Request.t(), keyword()) ::
          {:ok, StreamResponse.t()} | {:error, term()}
  def stream_request(%Request{} = request, opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, @default_name)
    timeout = Keyword.get(opts, :receive_timeout, @default_receive_timeout)

    do_request(request, name, fn pool ->
      pool_mod = detect_pool_module(pool)

      pool_mod.stream_request(
        pool,
        request.method,
        build_path(request.url),
        request.headers,
        request.body,
        timeout: timeout
      )
    end)
  end

  defp do_request(%Request{} = request, name, execute_fn) do
    uri = request.url
    origin = {scheme_to_atom(uri.scheme), uri.host, uri.port || default_port(uri.scheme)}
    metadata = %{request: request, origin: origin, name: name}

    Telemetry.span(Telemetry.request_event_prefix(), metadata, fn ->
      result =
        with {:ok, pool} <- Manager.get_pool(name, origin) do
          execute_fn.(pool)
        end

      extra =
        case result do
          {:ok, %Response{} = response} -> %{response: response}
          {:ok, %StreamResponse{} = stream_response} -> %{stream_response: stream_response}
          {:error, _} -> %{}
        end

      {result, Map.merge(metadata, extra)}
    end)
  end

  defp detect_pool_module(pool) do
    if pool_registered?(PoolHTTP2, pool), do: PoolHTTP2, else: PoolHTTP1
  end

  defp pool_registered?(module, pool) do
    :persistent_term.get({module, pool}, nil) != nil
  end

  @doc """
  Returns pool stats `%{idle, active, queued}` for the given URL's origin.

  ## Options

  - `:name` -- atom identifying the `Quiver.Supervisor` (default: `Quiver.Pool`)
  """
  @spec pool_stats(String.t(), keyword()) :: {:ok, map()} | {:error, :not_found}
  def pool_stats(url, opts \\ []) when is_binary(url) do
    name = Keyword.get(opts, :name, @default_name)
    uri = URI.parse(url)
    origin = {scheme_to_atom(uri.scheme), uri.host, uri.port || default_port(uri.scheme)}
    Manager.pool_stats(name, origin)
  end

  defp scheme_to_atom("https"), do: :https
  defp scheme_to_atom("http"), do: :http

  defp default_port("https"), do: 443
  defp default_port("http"), do: 80
  defp default_port(_), do: 80

  defp build_path(%URI{path: nil, query: nil}), do: "/"
  defp build_path(%URI{path: path, query: nil}), do: path
  defp build_path(%URI{path: nil, query: query}), do: "/?#{query}"
  defp build_path(%URI{path: path, query: query}), do: "#{path}?#{query}"
end
