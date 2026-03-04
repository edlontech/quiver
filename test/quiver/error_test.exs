defmodule Quiver.ErrorTest do
  use ExUnit.Case, async: true

  alias Quiver.Error
  alias Quiver.Error.CheckoutTimeout
  alias Quiver.Error.ConnectionClosed
  alias Quiver.Error.ConnectionRefused
  alias Quiver.Error.DNSResolutionFailed
  alias Quiver.Error.InvalidContentLength
  alias Quiver.Error.InvalidPoolOpts
  alias Quiver.Error.InvalidPoolRule
  alias Quiver.Error.InvalidScheme
  alias Quiver.Error.MalformedHeaders
  alias Quiver.Error.PoolStartFailed
  alias Quiver.Error.ProtocolViolation
  alias Quiver.Error.Timeout
  alias Quiver.Error.TLSHandshakeFailed
  alias Quiver.Error.TLSVerificationFailed

  describe "error class membership" do
    test "Timeout is a transient error" do
      error = Timeout.exception(message: "connect timed out")
      assert error.class == :transient
    end

    test "ConnectionClosed is a transient error" do
      error = ConnectionClosed.exception(message: "peer closed")
      assert error.class == :transient
    end

    test "ConnectionRefused is a transient error" do
      error = ConnectionRefused.exception(message: "refused")
      assert error.class == :transient
    end

    test "DNSResolutionFailed is a transient error" do
      error = DNSResolutionFailed.exception(host: "nope.invalid")
      assert error.class == :transient
    end

    test "TLSVerificationFailed is an unrecoverable error" do
      error = TLSVerificationFailed.exception(host: "example.com")
      assert error.class == :unrecoverable
    end

    test "TLSHandshakeFailed is an unrecoverable error" do
      error = TLSHandshakeFailed.exception(reason: :insufficient_security)
      assert error.class == :unrecoverable
    end

    test "InvalidScheme is an invalid error" do
      error = InvalidScheme.exception(scheme: "ftp")
      assert error.class == :invalid
    end

    test "ProtocolViolation is an unrecoverable error" do
      error = ProtocolViolation.exception(message: "bad status line")
      assert error.class == :unrecoverable
    end

    test "MalformedHeaders is an invalid error" do
      error = MalformedHeaders.exception(message: "missing colon")
      assert error.class == :invalid
    end

    test "InvalidContentLength is an invalid error" do
      error = InvalidContentLength.exception(message: "not a number")
      assert error.class == :invalid
    end

    test "CheckoutTimeout is a transient error" do
      error = CheckoutTimeout.exception(origin: "http://localhost:4000", timeout: 5_000)
      assert error.class == :transient
      assert error.origin == "http://localhost:4000"
      assert error.timeout == 5_000
    end

    test "InvalidPoolOpts is an invalid error" do
      error = InvalidPoolOpts.exception(errors: ["size must be positive"])
      assert error.class == :invalid
    end

    test "InvalidPoolRule is an invalid error" do
      error = InvalidPoolRule.exception(rule: "https://[bad", reason: "invalid URI")
      assert error.class == :invalid
    end

    test "PoolStartFailed is a transient error" do
      error =
        PoolStartFailed.exception(origin: {:https, "example.com", 443}, reason: :max_children)

      assert error.class == :transient
      assert error.origin == {:https, "example.com", 443}
      assert error.reason == :max_children
    end
  end

  describe "splode_error?/1" do
    test "recognizes quiver errors" do
      error = Timeout.exception(message: "timed out")
      assert Error.splode_error?(error)
    end

    test "rejects non-splode values" do
      refute Error.splode_error?("not an error")
    end
  end

  describe "to_class/1" do
    test "aggregates errors into class container" do
      error = Timeout.exception(message: "timed out")
      class_error = Error.to_class(error)
      assert class_error.class == :transient
      assert length(class_error.errors) == 1
    end
  end

  describe "error messages" do
    test "Timeout includes the message" do
      error = Timeout.exception(message: "connect timed out")
      assert Exception.message(error) =~ "connect timed out"
    end

    test "DNSResolutionFailed includes the host" do
      error = DNSResolutionFailed.exception(host: "nope.invalid")
      assert Exception.message(error) =~ "nope.invalid"
    end

    test "InvalidScheme includes the scheme" do
      error = InvalidScheme.exception(scheme: "ftp")
      assert Exception.message(error) =~ "ftp"
    end

    test "TLSVerificationFailed includes the host" do
      error = TLSVerificationFailed.exception(host: "evil.com")
      assert Exception.message(error) =~ "evil.com"
    end

    test "TLSHandshakeFailed includes the reason" do
      error = TLSHandshakeFailed.exception(reason: :insufficient_security)
      assert Exception.message(error) =~ "insufficient_security"
    end

    test "ConnectionRefused includes the message" do
      error = ConnectionRefused.exception(message: "connection refused")
      assert Exception.message(error) =~ "connection refused"
    end

    test "ConnectionClosed includes the message" do
      error = ConnectionClosed.exception(message: "peer closed")
      assert Exception.message(error) =~ "peer closed"
    end

    test "ProtocolViolation includes the message" do
      error = ProtocolViolation.exception(message: "bad status line")
      assert Exception.message(error) =~ "bad status line"
    end

    test "MalformedHeaders includes the message" do
      error = MalformedHeaders.exception(message: "missing colon")
      assert Exception.message(error) =~ "missing colon"
    end

    test "InvalidContentLength includes the message" do
      error = InvalidContentLength.exception(message: "not a number")
      assert Exception.message(error) =~ "not a number"
    end

    test "CheckoutTimeout includes origin and timeout" do
      error = CheckoutTimeout.exception(origin: "http://localhost:4000", timeout: 5_000)
      assert Exception.message(error) =~ "checkout timeout"
      assert Exception.message(error) =~ "5000"
      assert Exception.message(error) =~ "localhost:4000"
    end

    test "InvalidPoolOpts includes the errors" do
      error = InvalidPoolOpts.exception(errors: ["size must be positive"])
      assert Exception.message(error) =~ "size must be positive"
    end

    test "InvalidPoolRule includes rule and reason" do
      error = InvalidPoolRule.exception(rule: "https://[bad", reason: "invalid URI")
      assert Exception.message(error) =~ "invalid pool rule"
      assert Exception.message(error) =~ "invalid URI"
    end

    test "PoolStartFailed includes origin and reason" do
      error =
        PoolStartFailed.exception(origin: {:https, "example.com", 443}, reason: :max_children)

      assert Exception.message(error) =~ "pool start failed"
      assert Exception.message(error) =~ "example.com"
    end
  end
end
