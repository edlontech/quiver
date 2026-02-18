defmodule Quiver.Conn do
  @moduledoc """
  Behaviour for HTTP connection implementations.

  Connections are protocol-specific data structs (HTTP/1, HTTP/2, HTTP/3)
  that serialize requests and parse responses over a transport.

  All response fragments are tagged with a request reference for
  multiplexing support. HTTP/1 uses a single ref per request.
  """

  @type t :: struct()
  @type method :: :get | :head | :post | :put | :delete | :patch | :options | :trace | :connect
  @type headers :: [{String.t(), String.t()}]
  @type response_fragment ::
          {:status, reference(), non_neg_integer()}
          | {:headers, reference(), headers()}
          | {:data, reference(), binary()}
          | {:done, reference()}
          | {:error, reference(), term()}

  @callback connect(uri :: URI.t(), opts :: keyword()) ::
              {:ok, t()} | {:error, term()}

  @callback request(conn :: t(), method(), path :: String.t(), headers(), body :: iodata() | nil) ::
              {:ok, t(), Quiver.Response.t()} | {:error, t(), term()}

  @callback stream(conn :: t(), message :: term()) ::
              {:ok, t(), [response_fragment()]} | {:error, t(), term()} | :unknown

  @callback open?(conn :: t()) :: boolean()

  @callback close(conn :: t()) :: {:ok, t()}

  @callback open_request(
              conn :: t(),
              method(),
              path :: String.t(),
              headers(),
              body :: iodata() | nil
            ) ::
              {:ok, t(), reference()} | {:error, t(), term()}

  @callback cancel(conn :: t(), ref :: reference()) ::
              {:ok, t()} | {:error, t(), term()}

  @callback open_request_count(conn :: t()) :: non_neg_integer()

  @callback max_concurrent_streams(conn :: t()) :: non_neg_integer()

  @optional_callbacks [
    open_request: 5,
    cancel: 2,
    open_request_count: 1,
    max_concurrent_streams: 1
  ]
end
