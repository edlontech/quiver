defmodule Quiver.Conn.HTTP2.FrameTest do
  use ExUnit.Case, async: true

  alias Quiver.Conn.HTTP2.Frame

  describe "decode/1" do
    test "decodes DATA frame" do
      payload = "hello"
      frame = encode_raw(0x0, 0x0, 1, payload)

      assert {:ok, {:data, 1, 0x0, "hello"}, ""} = Frame.decode(frame)
    end

    test "decodes DATA frame with END_STREAM" do
      payload = "bye"
      frame = encode_raw(0x0, 0x1, 1, payload)

      assert {:ok, {:data, 1, 0x1, "bye"}, ""} = Frame.decode(frame)
    end

    test "decodes DATA frame with padding" do
      pad_length = 3
      payload = <<pad_length::8, "data", 0, 0, 0>>
      frame = encode_raw(0x0, 0x8, 1, payload)

      assert {:ok, {:data, 1, 0x8, "data"}, ""} = Frame.decode(frame)
    end

    test "decodes HEADERS frame" do
      header_block = "encoded-headers"
      frame = encode_raw(0x1, 0x4, 1, header_block)

      assert {:ok, {:headers, 1, 0x4, "encoded-headers", nil}, ""} = Frame.decode(frame)
    end

    test "decodes HEADERS frame with priority" do
      priority = <<0::1, 5::31, 15::8>>
      header_block = "headers"
      frame = encode_raw(0x1, 0x24, 1, priority <> header_block)

      assert {:ok,
              {:headers, 1, 0x24, "headers",
               %{exclusive: false, stream_dependency: 5, weight: 16}}, ""} =
               Frame.decode(frame)
    end

    test "decodes PRIORITY frame" do
      payload = <<1::1, 3::31, 255::8>>
      frame = encode_raw(0x2, 0x0, 5, payload)

      assert {:ok, {:priority, 5, true, 3, 256}, ""} = Frame.decode(frame)
    end

    test "returns error for invalid PRIORITY size" do
      frame = encode_raw(0x2, 0x0, 5, "ab")

      assert {:error, :frame_size_error} = Frame.decode(frame)
    end

    test "decodes RST_STREAM frame" do
      payload = <<0x8::32>>
      frame = encode_raw(0x3, 0x0, 1, payload)

      assert {:ok, {:rst_stream, 1, 0x8}, ""} = Frame.decode(frame)
    end

    test "returns error for invalid RST_STREAM size" do
      frame = encode_raw(0x3, 0x0, 1, "ab")

      assert {:error, :frame_size_error} = Frame.decode(frame)
    end

    test "decodes SETTINGS frame" do
      payload = <<0x3::16, 128::32, 0x4::16, 65_535::32>>
      frame = encode_raw(0x4, 0x0, 0, payload)

      assert {:ok, {:settings, :no_ack, settings}, ""} = Frame.decode(frame)
      assert {:max_concurrent_streams, 128} in settings
      assert {:initial_window_size, 65_535} in settings
    end

    test "decodes SETTINGS ACK" do
      frame = encode_raw(0x4, 0x1, 0, <<>>)

      assert {:ok, {:settings, :ack, []}, ""} = Frame.decode(frame)
    end

    test "returns error for SETTINGS ACK with payload" do
      frame = encode_raw(0x4, 0x1, 0, <<0x1::16, 4096::32>>)

      assert {:error, :frame_size_error} = Frame.decode(frame)
    end

    test "returns error for SETTINGS on non-zero stream" do
      frame = encode_raw(0x4, 0x0, 1, <<0x1::16, 4096::32>>)

      assert {:error, :protocol_error} = Frame.decode(frame)
    end

    test "decodes PUSH_PROMISE frame" do
      payload = <<0::1, 4::31, "headers">>
      frame = encode_raw(0x5, 0x4, 1, payload)

      assert {:ok, {:push_promise, 1, 0x4, 4, "headers"}, ""} = Frame.decode(frame)
    end

    test "decodes PING frame" do
      opaque = :binary.copy(<<42>>, 8)
      frame = encode_raw(0x6, 0x0, 0, opaque)

      assert {:ok, {:ping, :no_ack, ^opaque}, ""} = Frame.decode(frame)
    end

    test "decodes PING ACK" do
      opaque = :binary.copy(<<99>>, 8)
      frame = encode_raw(0x6, 0x1, 0, opaque)

      assert {:ok, {:ping, :ack, ^opaque}, ""} = Frame.decode(frame)
    end

    test "returns error for PING with wrong size" do
      frame = encode_raw(0x6, 0x0, 0, "short")

      assert {:error, :frame_size_error} = Frame.decode(frame)
    end

    test "returns error for PING on non-zero stream" do
      opaque = :binary.copy(<<0>>, 8)
      frame = encode_raw(0x6, 0x0, 5, opaque)

      assert {:error, :protocol_error} = Frame.decode(frame)
    end

    test "decodes GOAWAY frame" do
      payload = <<0::1, 7::31, 0x0::32, "debug">>
      frame = encode_raw(0x7, 0x0, 0, payload)

      assert {:ok, {:goaway, 7, 0x0, "debug"}, ""} = Frame.decode(frame)
    end

    test "decodes GOAWAY with empty debug data" do
      payload = <<0::1, 0::31, 0x0::32>>
      frame = encode_raw(0x7, 0x0, 0, payload)

      assert {:ok, {:goaway, 0, 0x0, ""}, ""} = Frame.decode(frame)
    end

    test "returns error for GOAWAY on non-zero stream" do
      payload = <<0::1, 0::31, 0x0::32>>
      frame = encode_raw(0x7, 0x0, 5, payload)

      assert {:error, :protocol_error} = Frame.decode(frame)
    end

    test "decodes WINDOW_UPDATE frame" do
      payload = <<0::1, 1000::31>>
      frame = encode_raw(0x8, 0x0, 0, payload)

      assert {:ok, {:window_update, 0, 1000}, ""} = Frame.decode(frame)
    end

    test "decodes WINDOW_UPDATE on specific stream" do
      payload = <<0::1, 500::31>>
      frame = encode_raw(0x8, 0x0, 3, payload)

      assert {:ok, {:window_update, 3, 500}, ""} = Frame.decode(frame)
    end

    test "returns error for WINDOW_UPDATE with zero increment" do
      payload = <<0::1, 0::31>>
      frame = encode_raw(0x8, 0x0, 0, payload)

      assert {:error, :protocol_error} = Frame.decode(frame)
    end

    test "decodes CONTINUATION frame" do
      header_block = "more-headers"
      frame = encode_raw(0x9, 0x4, 1, header_block)

      assert {:ok, {:continuation, 1, 0x4, "more-headers"}, ""} = Frame.decode(frame)
    end

    test "decodes unknown frame type" do
      frame = encode_raw(0xFF, 0x0, 1, "custom")

      assert {:ok, {:unknown, 0xFF, 1, 0x0, "custom"}, ""} = Frame.decode(frame)
    end

    test "returns :more for partial header" do
      assert :more = Frame.decode(<<0, 0>>)
    end

    test "returns :more for incomplete payload" do
      header = <<0, 0, 10, 0x0, 0x0, 0::1, 1::31>>
      assert :more = Frame.decode(header <> "short")
    end

    test "returns :more for empty binary" do
      assert :more = Frame.decode(<<>>)
    end

    test "preserves remaining bytes after frame" do
      payload = "data"
      frame = encode_raw(0x0, 0x0, 1, payload) <> "extra"

      assert {:ok, {:data, 1, 0x0, "data"}, "extra"} = Frame.decode(frame)
    end

    test "decodes multiple frames from buffer" do
      frame1 = encode_raw(0x0, 0x0, 1, "first")
      frame2 = encode_raw(0x0, 0x1, 1, "second")
      buffer = frame1 <> frame2

      assert {:ok, {:data, 1, 0x0, "first"}, rest} = Frame.decode(buffer)
      assert {:ok, {:data, 1, 0x1, "second"}, ""} = Frame.decode(rest)
    end
  end

  describe "encode round-trips" do
    test "DATA frame" do
      encoded = Frame.encode_data(1, "hello", false) |> IO.iodata_to_binary()
      assert {:ok, {:data, 1, flags, "hello"}, ""} = Frame.decode(encoded)
      refute Frame.flag_set?(flags, 0x1)
    end

    test "DATA frame with END_STREAM" do
      encoded = Frame.encode_data(3, "bye", true) |> IO.iodata_to_binary()
      assert {:ok, {:data, 3, flags, "bye"}, ""} = Frame.decode(encoded)
      assert Frame.flag_set?(flags, 0x1)
    end

    test "HEADERS frame" do
      encoded = Frame.encode_headers(1, "hdr", true, false) |> IO.iodata_to_binary()
      assert {:ok, {:headers, 1, flags, "hdr", nil}, ""} = Frame.decode(encoded)
      assert Frame.flag_set?(flags, 0x4)
      refute Frame.flag_set?(flags, 0x1)
    end

    test "HEADERS frame with END_STREAM" do
      encoded = Frame.encode_headers(1, "hdr", true, true) |> IO.iodata_to_binary()
      assert {:ok, {:headers, 1, flags, "hdr", nil}, ""} = Frame.decode(encoded)
      assert Frame.flag_set?(flags, 0x4)
      assert Frame.flag_set?(flags, 0x1)
    end

    test "SETTINGS frame" do
      settings = [{0x3, 128}, {0x4, 65_535}]
      encoded = Frame.encode_settings(settings) |> IO.iodata_to_binary()
      assert {:ok, {:settings, :no_ack, decoded}, ""} = Frame.decode(encoded)
      assert {:max_concurrent_streams, 128} in decoded
      assert {:initial_window_size, 65_535} in decoded
    end

    test "SETTINGS ACK" do
      encoded = Frame.encode_settings_ack() |> IO.iodata_to_binary()
      assert {:ok, {:settings, :ack, []}, ""} = Frame.decode(encoded)
    end

    test "WINDOW_UPDATE frame" do
      encoded = Frame.encode_window_update(0, 32_768) |> IO.iodata_to_binary()
      assert {:ok, {:window_update, 0, 32_768}, ""} = Frame.decode(encoded)
    end

    test "WINDOW_UPDATE on stream" do
      encoded = Frame.encode_window_update(5, 1024) |> IO.iodata_to_binary()
      assert {:ok, {:window_update, 5, 1024}, ""} = Frame.decode(encoded)
    end

    test "PING frame" do
      opaque = <<1, 2, 3, 4, 5, 6, 7, 8>>
      encoded = Frame.encode_ping(opaque) |> IO.iodata_to_binary()
      assert {:ok, {:ping, :no_ack, ^opaque}, ""} = Frame.decode(encoded)
    end

    test "PONG frame" do
      opaque = <<8, 7, 6, 5, 4, 3, 2, 1>>
      encoded = Frame.encode_pong(opaque) |> IO.iodata_to_binary()
      assert {:ok, {:ping, :ack, ^opaque}, ""} = Frame.decode(encoded)
    end

    test "GOAWAY frame" do
      encoded = Frame.encode_goaway(10, 0x0, "no error") |> IO.iodata_to_binary()
      assert {:ok, {:goaway, 10, 0x0, "no error"}, ""} = Frame.decode(encoded)
    end

    test "RST_STREAM frame" do
      encoded = Frame.encode_rst_stream(3, 0x8) |> IO.iodata_to_binary()
      assert {:ok, {:rst_stream, 3, 0x8}, ""} = Frame.decode(encoded)
    end

    test "CONTINUATION frame" do
      encoded = Frame.encode_continuation(1, "cont", true) |> IO.iodata_to_binary()
      assert {:ok, {:continuation, 1, flags, "cont"}, ""} = Frame.decode(encoded)
      assert Frame.flag_set?(flags, 0x4)
    end
  end

  defp encode_raw(type, flags, stream_id, payload) do
    length = byte_size(payload)
    <<length::24, type::8, flags::8, 0::1, stream_id::31, payload::binary>>
  end
end
