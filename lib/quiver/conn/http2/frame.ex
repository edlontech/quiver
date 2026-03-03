defmodule Quiver.Conn.HTTP2.Frame do
  @moduledoc """
  HTTP/2 frame encode/decode per RFC 9113.

  All frames share a 9-byte header:

      +-----------------------------------------------+
      | Length (24) | Type (8) | Flags (8)             |
      +-----------------------------------------------+
      | Reserved (1) | Stream Identifier (31)          |
      +-----------------------------------------------+
      | Frame Payload (Length bytes)                    |
      +-----------------------------------------------+
  """

  import Bitwise

  @frame_header_size 9

  @data 0x0
  @headers 0x1
  @priority 0x2
  @rst_stream 0x3
  @settings 0x4
  @push_promise 0x5
  @ping 0x6
  @goaway 0x7
  @window_update 0x8
  @continuation 0x9

  @flag_end_stream 0x1
  @flag_ack 0x1
  @flag_end_headers 0x4
  @flag_padded 0x8
  @flag_priority 0x20

  @settings_header_table_size 0x1
  @settings_enable_push 0x2
  @settings_max_concurrent_streams 0x3
  @settings_initial_window_size 0x4
  @settings_max_frame_size 0x5
  @settings_max_header_list_size 0x6

  # -- Decode --

  @doc false
  @spec decode(binary()) :: {:ok, tuple(), binary()} | :more | {:error, term()}
  def decode(
        <<length::24, type::8, flags::8, _reserved::1, stream_id::31,
          payload::binary-size(length), rest::binary>>
      ) do
    case decode_payload(type, flags, stream_id, payload) do
      {:ok, frame} -> {:ok, frame, rest}
      {:error, _} = error -> error
    end
  end

  def decode(data) when byte_size(data) < @frame_header_size, do: :more

  def decode(<<length::24, _type::8, _flags::8, _reserved::1, _stream_id::31, rest::binary>>)
      when byte_size(rest) < length,
      do: :more

  # DATA (0x0)
  defp decode_payload(@data, flags, stream_id, payload) do
    case strip_padding(flags, payload) do
      {:ok, data} -> {:ok, {:data, stream_id, flags, data}}
      {:error, _} = error -> error
    end
  end

  # HEADERS (0x1)
  defp decode_payload(@headers, flags, stream_id, payload) do
    with {:ok, rest} <- strip_padding(flags, payload),
         {:ok, header_block, priority_fields} <- strip_priority(flags, rest) do
      {:ok, {:headers, stream_id, flags, header_block, priority_fields}}
    end
  end

  # PRIORITY (0x2)
  defp decode_payload(@priority, _flags, stream_id, <<e::1, dep::31, weight::8>>) do
    {:ok, {:priority, stream_id, e == 1, dep, weight + 1}}
  end

  defp decode_payload(@priority, _flags, _stream_id, _payload) do
    {:error, :frame_size_error}
  end

  # RST_STREAM (0x3)
  defp decode_payload(@rst_stream, _flags, stream_id, <<error_code::32>>) do
    {:ok, {:rst_stream, stream_id, error_code}}
  end

  defp decode_payload(@rst_stream, _flags, _stream_id, _payload) do
    {:error, :frame_size_error}
  end

  # SETTINGS (0x4)
  defp decode_payload(@settings, flags, 0, payload) do
    if flag_set?(flags, @flag_ack) do
      if byte_size(payload) == 0 do
        {:ok, {:settings, :ack, []}}
      else
        {:error, :frame_size_error}
      end
    else
      case decode_settings_pairs(payload, []) do
        {:ok, settings} -> {:ok, {:settings, :no_ack, settings}}
        {:error, _} = error -> error
      end
    end
  end

  defp decode_payload(@settings, _flags, _stream_id, _payload) do
    {:error, :protocol_error}
  end

  # PUSH_PROMISE (0x5)
  defp decode_payload(@push_promise, flags, stream_id, payload) do
    case strip_padding(flags, payload) do
      {:ok, <<_reserved::1, promised_id::31, header_block::binary>>} ->
        {:ok, {:push_promise, stream_id, flags, promised_id, header_block}}

      {:ok, _} ->
        {:error, :frame_size_error}

      {:error, _} = error ->
        error
    end
  end

  # PING (0x6)
  defp decode_payload(@ping, flags, 0, <<opaque_data::binary-size(8)>>) do
    if flag_set?(flags, @flag_ack) do
      {:ok, {:ping, :ack, opaque_data}}
    else
      {:ok, {:ping, :no_ack, opaque_data}}
    end
  end

  defp decode_payload(@ping, _flags, 0, _payload), do: {:error, :frame_size_error}
  defp decode_payload(@ping, _flags, _stream_id, _payload), do: {:error, :protocol_error}

  # GOAWAY (0x7)
  defp decode_payload(
         @goaway,
         _flags,
         0,
         <<_r::1, last_stream_id::31, error_code::32, debug::binary>>
       ) do
    {:ok, {:goaway, last_stream_id, error_code, debug}}
  end

  defp decode_payload(@goaway, _flags, 0, _payload), do: {:error, :frame_size_error}
  defp decode_payload(@goaway, _flags, _stream_id, _payload), do: {:error, :protocol_error}

  # WINDOW_UPDATE (0x8)
  defp decode_payload(@window_update, _flags, stream_id, <<_r::1, increment::31>>) do
    if increment == 0 do
      {:error, :protocol_error}
    else
      {:ok, {:window_update, stream_id, increment}}
    end
  end

  defp decode_payload(@window_update, _flags, _stream_id, _payload) do
    {:error, :frame_size_error}
  end

  # CONTINUATION (0x9)
  defp decode_payload(@continuation, flags, stream_id, header_block) do
    {:ok, {:continuation, stream_id, flags, header_block}}
  end

  # Unknown frame type
  defp decode_payload(type, flags, stream_id, payload) do
    {:ok, {:unknown, type, stream_id, flags, payload}}
  end

  # -- Encode --

  @doc false
  @spec encode_data(non_neg_integer(), iodata(), boolean()) :: iodata()
  def encode_data(stream_id, payload, end_stream?) do
    flags = if end_stream?, do: @flag_end_stream, else: 0
    encode_frame(@data, flags, stream_id, payload)
  end

  @doc false
  @spec encode_headers(non_neg_integer(), iodata(), boolean(), boolean()) :: iodata()
  def encode_headers(stream_id, header_block, end_headers?, end_stream?) do
    flags = 0
    flags = if end_headers?, do: flags ||| @flag_end_headers, else: flags
    flags = if end_stream?, do: flags ||| @flag_end_stream, else: flags
    encode_frame(@headers, flags, stream_id, header_block)
  end

  @doc false
  @spec encode_settings([{non_neg_integer(), non_neg_integer()}]) :: iodata()
  def encode_settings(settings) do
    payload = Enum.map(settings, fn {id, value} -> <<id::16, value::32>> end)
    encode_frame(@settings, 0, 0, payload)
  end

  @doc false
  @spec encode_settings_ack() :: iodata()
  def encode_settings_ack do
    encode_frame(@settings, @flag_ack, 0, [])
  end

  @doc false
  @spec encode_window_update(non_neg_integer(), non_neg_integer()) :: iodata()
  def encode_window_update(stream_id, increment) do
    encode_frame(@window_update, 0, stream_id, <<0::1, increment::31>>)
  end

  @doc false
  @spec encode_ping(binary()) :: iodata()
  def encode_ping(opaque_data) when byte_size(opaque_data) == 8 do
    encode_frame(@ping, 0, 0, opaque_data)
  end

  @doc false
  @spec encode_pong(binary()) :: iodata()
  def encode_pong(opaque_data) when byte_size(opaque_data) == 8 do
    encode_frame(@ping, @flag_ack, 0, opaque_data)
  end

  @doc false
  @spec encode_goaway(non_neg_integer(), non_neg_integer(), binary()) :: iodata()
  def encode_goaway(last_stream_id, error_code, debug_data) do
    payload = [<<0::1, last_stream_id::31, error_code::32>>, debug_data]
    encode_frame(@goaway, 0, 0, payload)
  end

  @doc false
  @spec encode_rst_stream(non_neg_integer(), non_neg_integer()) :: iodata()
  def encode_rst_stream(stream_id, error_code) do
    encode_frame(@rst_stream, 0, stream_id, <<error_code::32>>)
  end

  @doc false
  @spec encode_continuation(non_neg_integer(), iodata(), boolean()) :: iodata()
  def encode_continuation(stream_id, header_block, end_headers?) do
    flags = if end_headers?, do: @flag_end_headers, else: 0
    encode_frame(@continuation, flags, stream_id, header_block)
  end

  # -- Helpers --

  @doc false
  @spec flag_set?(non_neg_integer(), non_neg_integer()) :: boolean()
  def flag_set?(flags, flag), do: (flags &&& flag) == flag

  defp encode_frame(type, flags, stream_id, payload) do
    length = IO.iodata_length(payload)
    [<<length::24, type::8, flags::8, 0::1, stream_id::31>>, payload]
  end

  defp strip_padding(flags, payload) do
    if flag_set?(flags, @flag_padded) do
      do_strip_padding(payload)
    else
      {:ok, payload}
    end
  end

  defp do_strip_padding(<<pad_length::8, rest::binary>>) do
    data_length = byte_size(rest) - pad_length

    if data_length >= 0 do
      <<data::binary-size(data_length), _padding::binary>> = rest
      {:ok, data}
    else
      {:error, :protocol_error}
    end
  end

  defp do_strip_padding(_payload), do: {:error, :frame_size_error}

  defp strip_priority(flags, payload) do
    if flag_set?(flags, @flag_priority) do
      case payload do
        <<e::1, dep::31, weight::8, header_block::binary>> ->
          {:ok, header_block, %{exclusive: e == 1, stream_dependency: dep, weight: weight + 1}}

        _ ->
          {:error, :frame_size_error}
      end
    else
      {:ok, payload, nil}
    end
  end

  defp decode_settings_pairs(<<>>, acc), do: {:ok, Enum.reverse(acc)}

  defp decode_settings_pairs(<<id::16, value::32, rest::binary>>, acc) do
    setting = {settings_id_to_atom(id), value}
    decode_settings_pairs(rest, [setting | acc])
  end

  defp decode_settings_pairs(_binary, _acc), do: {:error, :frame_size_error}

  defp settings_id_to_atom(@settings_header_table_size), do: :header_table_size
  defp settings_id_to_atom(@settings_enable_push), do: :enable_push
  defp settings_id_to_atom(@settings_max_concurrent_streams), do: :max_concurrent_streams
  defp settings_id_to_atom(@settings_initial_window_size), do: :initial_window_size
  defp settings_id_to_atom(@settings_max_frame_size), do: :max_frame_size
  defp settings_id_to_atom(@settings_max_header_list_size), do: :max_header_list_size
  defp settings_id_to_atom(id), do: {:unknown, id}

  @doc false
  @spec settings_atom_to_id(atom()) :: non_neg_integer()
  def settings_atom_to_id(:header_table_size), do: @settings_header_table_size
  def settings_atom_to_id(:enable_push), do: @settings_enable_push
  def settings_atom_to_id(:max_concurrent_streams), do: @settings_max_concurrent_streams
  def settings_atom_to_id(:initial_window_size), do: @settings_initial_window_size
  def settings_atom_to_id(:max_frame_size), do: @settings_max_frame_size
  def settings_atom_to_id(:max_header_list_size), do: @settings_max_header_list_size
end
