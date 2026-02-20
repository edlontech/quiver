defmodule Quiver.Pool do
  @moduledoc """
  Common interface for protocol-specific pool implementations.

  Both `Quiver.Pool.HTTP1` and `Quiver.Pool.HTTP2` implement this behaviour,
  allowing `Quiver.Pool.Manager` to dispatch requests without knowing the
  underlying protocol.
  """

  alias Quiver.Response

  @type method :: Quiver.Conn.method()
  @type headers :: Quiver.Conn.headers()

  @callback request(
              pool :: pid(),
              method(),
              path :: String.t(),
              headers(),
              body :: iodata() | nil,
              opts :: keyword()
            ) :: {:ok, Response.t()} | {:error, term()}

  @callback stream_request(
              pool :: pid(),
              method(),
              path :: String.t(),
              headers(),
              body :: iodata() | nil,
              opts :: keyword()
            ) :: {:ok, Quiver.StreamResponse.t()} | {:error, term()}

  @callback stats(pool :: pid()) :: %{
              required(:idle) => non_neg_integer(),
              required(:active) => non_neg_integer(),
              required(:queued) => non_neg_integer(),
              optional(:connections) => non_neg_integer()
            }
end
