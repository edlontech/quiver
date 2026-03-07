defmodule Quiver.Conn.HTTP2.Errors do
  @moduledoc false

  @error_codes %{
    0x0 => :no_error,
    0x1 => :protocol_error,
    0x2 => :internal_error,
    0x3 => :flow_control_error,
    0x4 => :settings_timeout,
    0x5 => :stream_closed,
    0x6 => :frame_size_error,
    0x7 => :refused_stream,
    0x8 => :cancel,
    0x9 => :compression_error,
    0xA => :connect_error,
    0xB => :enhance_your_calm,
    0xC => :inadequate_security,
    0xD => :http_1_1_required
  }

  @type error_code ::
          :no_error
          | :protocol_error
          | :internal_error
          | :flow_control_error
          | :settings_timeout
          | :stream_closed
          | :frame_size_error
          | :refused_stream
          | :cancel
          | :compression_error
          | :connect_error
          | :enhance_your_calm
          | :inadequate_security
          | :http_1_1_required

  @reverse_codes Map.new(@error_codes, fn {k, v} -> {v, k} end)

  @doc false
  @spec decode(non_neg_integer()) :: error_code() | {:unknown, non_neg_integer()}
  for {code, atom} <- @error_codes do
    def decode(unquote(code)), do: unquote(atom)
  end

  def decode(code) when is_integer(code), do: {:unknown, code}

  @doc false
  @spec encode(error_code() | {:unknown, non_neg_integer()} | non_neg_integer()) ::
          non_neg_integer()
  for {atom, code} <- @reverse_codes do
    def encode(unquote(atom)), do: unquote(code)
  end

  def encode({:unknown, code}) when is_integer(code), do: code
  def encode(code) when is_integer(code), do: code
end
