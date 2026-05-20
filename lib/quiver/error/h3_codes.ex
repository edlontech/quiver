defmodule Quiver.Error.H3Codes do
  @moduledoc """
  HTTP/3 error code constants (RFC 9114 Section 8.1) and decode helper.
  Mirrors `lib/quiver/conn/http2/errors.ex` for h2.
  """

  @codes %{
    0x100 => :h3_no_error,
    0x101 => :h3_general_protocol_error,
    0x102 => :h3_internal_error,
    0x103 => :h3_stream_creation_error,
    0x104 => :h3_closed_critical_stream,
    0x105 => :h3_frame_unexpected,
    0x106 => :h3_frame_error,
    0x107 => :h3_excessive_load,
    0x108 => :h3_id_error,
    0x109 => :h3_settings_error,
    0x10A => :h3_missing_settings,
    0x10B => :h3_request_rejected,
    0x10C => :h3_request_cancelled,
    0x10D => :h3_request_incomplete,
    0x10E => :h3_message_error,
    0x10F => :h3_connect_error,
    0x110 => :h3_version_fallback
  }

  @type error_code ::
          :h3_no_error
          | :h3_general_protocol_error
          | :h3_internal_error
          | :h3_stream_creation_error
          | :h3_closed_critical_stream
          | :h3_frame_unexpected
          | :h3_frame_error
          | :h3_excessive_load
          | :h3_id_error
          | :h3_settings_error
          | :h3_missing_settings
          | :h3_request_rejected
          | :h3_request_cancelled
          | :h3_request_incomplete
          | :h3_message_error
          | :h3_connect_error
          | :h3_version_fallback

  @doc "Decode an H3 error code to its atom name, or `{:unknown, code}` if not in the table."
  @spec decode(non_neg_integer()) :: error_code() | {:unknown, non_neg_integer()}
  for {code, atom} <- @codes do
    def decode(unquote(code)), do: unquote(atom)
  end

  def decode(code) when is_integer(code), do: {:unknown, code}

  @doc "All known H3 error codes as a `{code, atom}` list."
  @spec list() :: [{non_neg_integer(), error_code()}]
  def list, do: unquote(Macro.escape(Map.to_list(@codes)))
end
