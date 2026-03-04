if Code.ensure_loaded?(Tesla) do
  defmodule Tesla.Adapter.Quiver do
    @moduledoc """
    Tesla adapter for the Quiver HTTP client.

    ## Usage

        # Using the default Quiver.Pool supervisor:
        defmodule MyClient do
          use Tesla
          adapter Tesla.Adapter.Quiver
        end

        # Using a custom supervisor name:
        defmodule MyClient do
          use Tesla
          adapter Tesla.Adapter.Quiver, name: :my_quiver
        end

    ## Options

      * `:name` - atom identifying the running `Quiver.Supervisor` (default: `Quiver.Pool`)
      * `:response` - set to `:stream` for streaming response body (default: buffered)
      * `:receive_timeout` - max ms to wait per response chunk (default: 15,000)

    ## Streaming

    When `response: :stream` is set, the adapter uses `Quiver.stream_request/2`
    and returns a `Tesla.Env` with a lazy body stream. Note that some Tesla
    middleware expects a fully buffered body and may not work in streaming mode.
    """

    @behaviour Tesla.Adapter

    @impl Tesla.Adapter
    def call(env, opts) do
      adapter_opts = Tesla.Adapter.opts(env, opts)
      request = build_request(env)
      quiver_opts = build_quiver_opts(adapter_opts)

      case adapter_opts[:response] do
        :stream -> do_stream_request(env, request, quiver_opts)
        _ -> do_request(env, request, quiver_opts)
      end
    end

    defp build_request(env) do
      url = Tesla.build_url(env)

      env.method
      |> Quiver.new(url)
      |> set_headers(env.headers)
      |> set_body(env.body)
    end

    defp set_headers(request, headers) do
      Enum.reduce(headers, request, fn {key, value}, req ->
        Quiver.header(req, key, value)
      end)
    end

    defp set_body(request, nil), do: request
    defp set_body(request, ""), do: request
    defp set_body(request, body), do: Quiver.body(request, body)

    defp build_quiver_opts(adapter_opts) do
      Keyword.take(adapter_opts, [:name, :receive_timeout])
    end

    defp do_request(%Tesla.Env{} = env, request, quiver_opts) do
      case Quiver.request(request, quiver_opts) do
        {:ok, response} ->
          {:ok,
           %Tesla.Env{
             env
             | status: response.status,
               headers: response.headers,
               body: response.body
           }}

        {:error, error} ->
          {:error, error}
      end
    end

    defp do_stream_request(%Tesla.Env{} = env, request, quiver_opts) do
      case Quiver.stream_request(request, quiver_opts) do
        {:ok, stream_response} ->
          {:ok,
           %Tesla.Env{
             env
             | status: stream_response.status,
               headers: stream_response.headers,
               body: stream_response.body
           }}

        {:error, error} ->
          {:error, error}
      end
    end
  end
end
