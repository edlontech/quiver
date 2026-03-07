defmodule Quiver.Conn.HTTP2.ErrorsTest do
  use ExUnit.Case, async: true

  alias Quiver.Conn.HTTP2.Errors

  describe "decode/1" do
    test "decodes all 14 RFC 9113 error codes" do
      assert Errors.decode(0x0) == :no_error
      assert Errors.decode(0x1) == :protocol_error
      assert Errors.decode(0x2) == :internal_error
      assert Errors.decode(0x3) == :flow_control_error
      assert Errors.decode(0x4) == :settings_timeout
      assert Errors.decode(0x5) == :stream_closed
      assert Errors.decode(0x6) == :frame_size_error
      assert Errors.decode(0x7) == :refused_stream
      assert Errors.decode(0x8) == :cancel
      assert Errors.decode(0x9) == :compression_error
      assert Errors.decode(0xA) == :connect_error
      assert Errors.decode(0xB) == :enhance_your_calm
      assert Errors.decode(0xC) == :inadequate_security
      assert Errors.decode(0xD) == :http_1_1_required
    end

    test "returns {:unknown, code} for unrecognized error codes" do
      assert Errors.decode(0xE) == {:unknown, 0xE}
      assert Errors.decode(0xFF) == {:unknown, 0xFF}
      assert Errors.decode(9999) == {:unknown, 9999}
    end
  end

  describe "encode/1" do
    test "encodes all 14 RFC 9113 error codes" do
      assert Errors.encode(:no_error) == 0x0
      assert Errors.encode(:protocol_error) == 0x1
      assert Errors.encode(:internal_error) == 0x2
      assert Errors.encode(:flow_control_error) == 0x3
      assert Errors.encode(:settings_timeout) == 0x4
      assert Errors.encode(:stream_closed) == 0x5
      assert Errors.encode(:frame_size_error) == 0x6
      assert Errors.encode(:refused_stream) == 0x7
      assert Errors.encode(:cancel) == 0x8
      assert Errors.encode(:compression_error) == 0x9
      assert Errors.encode(:connect_error) == 0xA
      assert Errors.encode(:enhance_your_calm) == 0xB
      assert Errors.encode(:inadequate_security) == 0xC
      assert Errors.encode(:http_1_1_required) == 0xD
    end

    test "passes through integer values unchanged" do
      assert Errors.encode(0x0) == 0x0
      assert Errors.encode(0x8) == 0x8
      assert Errors.encode(0xFF) == 0xFF
    end

    test "encodes {:unknown, code} tuples back to integers" do
      assert Errors.encode({:unknown, 0xE}) == 0xE
      assert Errors.encode({:unknown, 0xFF}) == 0xFF
    end
  end

  describe "round-trip" do
    test "decode then encode returns original integer for known codes" do
      for code <- 0x0..0xD do
        assert code |> Errors.decode() |> Errors.encode() == code
      end
    end

    test "decode then encode returns original integer for unknown codes" do
      for code <- [0xE, 0xFF, 9999] do
        assert code |> Errors.decode() |> Errors.encode() == code
      end
    end
  end
end
