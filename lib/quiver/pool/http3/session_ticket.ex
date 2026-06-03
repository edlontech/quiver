defmodule Quiver.Pool.HTTP3.SessionTicket do
  @moduledoc false
  # Read-only accessors for the opaque :quic `#session_ticket{}` record
  # (defined in quic/include/quic.hrl). Isolates the record-shape coupling to
  # a single module: on any shape mismatch the accessors return nil so callers
  # treat the ticket as usable and let the QUIC layer reject a stale/invalid
  # one at connect time.
  require Record

  @fields Record.extract(:session_ticket, from_lib: "quic/include/quic.hrl")
  Record.defrecordp(:session_ticket, @fields)

  @spec lifetime(term()) :: non_neg_integer() | nil
  def lifetime(ticket) when Record.is_record(ticket, :session_ticket) do
    session_ticket(ticket, :lifetime)
  end

  def lifetime(_other), do: nil

  @spec max_early_data(term()) :: non_neg_integer() | nil
  def max_early_data(ticket) when Record.is_record(ticket, :session_ticket) do
    session_ticket(ticket, :max_early_data)
  end

  def max_early_data(_other), do: nil
end
