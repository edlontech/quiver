defmodule Quiver.HTTP3.Channel do
  @moduledoc """
  Opaque handle returned by `Quiver.HTTP3.open_datagram_channel/4`.

  Carries the H/3 connection pid, stream id, and per-channel ref. Users
  pattern-match only via `%Quiver.HTTP3.Channel{}`.
  """

  @derive {Inspect, only: [:origin, :stream_id, :status]}

  @enforce_keys [:ref, :worker_pid, :h3_conn, :stream_id, :origin]
  defstruct [:ref, :worker_pid, :h3_conn, :stream_id, :origin, :status, :response_headers]

  @type t :: %__MODULE__{
          ref: reference(),
          worker_pid: pid(),
          h3_conn: pid(),
          stream_id: non_neg_integer(),
          origin: {atom(), String.t(), :inet.port_number()},
          status: nil | 100..599,
          response_headers: nil | [{binary(), binary()}]
        }
end
