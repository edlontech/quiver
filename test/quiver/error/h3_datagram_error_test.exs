defmodule Quiver.Error.H3DatagramErrorTest do
  use ExUnit.Case, async: true

  alias Quiver.Error.H3DatagramError

  test "default class is :transient" do
    err = H3DatagramError.exception(reason: :congestion_limited)
    assert err.class == :transient
  end

  test "formats reason in the message" do
    err = H3DatagramError.exception(reason: :too_large)
    assert Exception.message(err) =~ ":too_large"
  end

  test "preserves the reason atom" do
    err = H3DatagramError.exception(reason: :unknown_stream)
    assert err.reason == :unknown_stream
  end
end
