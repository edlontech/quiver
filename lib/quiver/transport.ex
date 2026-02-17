defmodule Quiver.Transport do
  @moduledoc """
  Behaviour for socket transports.

  Transports are passive by default. Use `activate/1` to switch to
  `{active, :once}` mode for receiving a single socket message.
  All callbacks return the (potentially updated) transport struct.
  """

  @type t :: struct()
  @type option :: {atom(), term()}

  @callback connect(host :: String.t(), port :: :inet.port_number(), opts :: [option()]) ::
              {:ok, t()} | {:error, term()}

  @callback send(transport :: t(), data :: iodata()) ::
              {:ok, t()} | {:error, t(), term()}

  @callback recv(transport :: t(), length :: non_neg_integer(), timeout :: timeout()) ::
              {:ok, t(), binary()} | {:error, t(), term()}

  @callback close(transport :: t()) ::
              {:ok, t()}

  @callback activate(transport :: t()) ::
              {:ok, t()} | {:error, t(), term()}

  @callback controlling_process(transport :: t(), pid :: pid()) ::
              {:ok, t()} | {:error, t(), term()}
end
