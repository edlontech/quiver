defmodule Quiver do
  @moduledoc """
  A mid-level HTTP client for Elixir supporting HTTP/1.1 and HTTP/2.

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
  alias Quiver.Upgrade

  @default_name Quiver.Pool
  @default_receive_timeout 15_000

  @doc "Returns the default supervisor name (`Quiver.Pool`)."
  @spec default_name() :: atom()
  def default_name, do: @default_name

  @doc """
  Creates a new request with the given HTTP method and URL.

  The URL is parsed into a `URI` struct and stored on the request.
  Combine with `header/3`, `body/2`, and `request/2` to build and execute
  the full request pipeline.

  ## Examples

      Quiver.new(:get, "https://example.com/api/users")

      Quiver.new(:post, "https://example.com/api/users")
      |> Quiver.header("content-type", "application/json")
      |> Quiver.body(~s({"name": "Ada"}))
      |> Quiver.request()
  """
  @spec new(Quiver.Conn.method(), String.t()) :: Request.t()
  def new(method, url) when is_atom(method) and is_binary(url) do
    %Request{method: method, url: URI.parse(url)}
  end

  @doc """
  Appends a header to the request.

  Headers are stored as a list of `{key, value}` tuples. Calling this
  multiple times with the same key adds duplicate headers (does not
  replace). Both key and value must be binaries.

  ## Examples

      request
      |> Quiver.header("authorization", "Bearer token")
      |> Quiver.header("accept", "application/json")
  """
  @spec header(Request.t(), String.t(), String.t()) :: Request.t()
  def header(%Request{} = request, key, value)
      when is_binary(key) and is_binary(value) do
    %{request | headers: request.headers ++ [{key, value}]}
  end

  @doc """
  Sets the request body.

  Accepts any `t:iodata/0` value. Overwrites any previously set body.

  ## Examples

      Quiver.new(:post, "https://example.com/api")
      |> Quiver.body(~s({"key": "value"}))

      Quiver.new(:put, "https://example.com/upload")
      |> Quiver.body(["chunk1", "chunk2"])
  """
  @spec body(Request.t(), iodata()) :: Request.t()
  def body(%Request{} = request, body) do
    %{request | body: body}
  end

  @doc """
  Sets a streaming body on the request.

  Wraps the given enumerable in a `{:stream, enumerable}` tagged tuple,
  replacing any previously set body. The enumerable will be consumed
  lazily when the request is sent.

  ## Examples

      Quiver.new(:post, "https://example.com/upload")
      |> Quiver.stream_body(Stream.map(chunks, &compress/1))
  """
  @spec stream_body(Request.t(), Enumerable.t()) :: Request.t()
  def stream_body(%Request{} = request, enumerable) do
    %{request | body: {:stream, enumerable}}
  end

  @doc """
  Executes the request and returns the full response.

  The entire response body is buffered in memory. For large responses,
  consider `stream_request/2` instead.

  Pools are selected automatically based on the request's origin
  (scheme + host + port) and the rules configured in `Quiver.Supervisor`.

  ## Options

  - `:name` -- atom identifying the `Quiver.Supervisor` (default: `Quiver.Pool`)
  - `:receive_timeout` -- max ms to wait for the response (default: 15,000)

  ## Examples

      {:ok, %Quiver.Response{status: 200, body: body}} =
        Quiver.new(:get, "https://example.com/api")
        |> Quiver.request()

      {:ok, resp} =
        Quiver.new(:get, "https://internal.api/data")
        |> Quiver.request(name: :internal_client, receive_timeout: 30_000)
  """
  @spec request(Request.t(), keyword()) ::
          {:ok, Response.t()} | {:upgrade, Upgrade.t()} | {:error, term()}
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
        receive_timeout: timeout
      )
    end)
  end

  @doc """
  Executes the request in streaming mode.

  Returns a `Quiver.StreamResponse` with eagerly-received `status` and
  `headers`, and a lazy `body` stream that yields binary chunks as the
  caller enumerates it. The underlying pool connection is held for the
  lifetime of the stream and released when the stream is fully consumed
  or halted.

  ## Options

  - `:name` -- atom identifying the `Quiver.Supervisor` (default: `Quiver.Pool`)
  - `:receive_timeout` -- max ms to wait per response chunk (default: 15,000)

  ## Examples

      {:ok, %Quiver.StreamResponse{status: 200, body: body_stream}} =
        Quiver.new(:get, "https://example.com/stream/100")
        |> Quiver.stream_request()

      body_stream
      |> Stream.each(&IO.write/1)
      |> Stream.run()
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
        receive_timeout: timeout
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
          {:upgrade, %Upgrade{} = upgrade} -> %{upgrade: upgrade}
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
  Returns pool statistics for the given URL's origin.

  The returned map contains:
  - `:idle` -- number of idle connections/stream slots
  - `:active` -- number of in-flight requests
  - `:queued` -- number of callers waiting for a connection

  Returns `{:error, :not_found}` if no pool exists for the origin yet.

  ## Options

  - `:name` -- atom identifying the `Quiver.Supervisor` (default: `Quiver.Pool`)

  ## Examples

      {:ok, %{idle: 8, active: 2, queued: 0}} =
        Quiver.pool_stats("https://example.com")
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
