defmodule Quiver.Error.H3DatagramsDisabledTest do
  use ExUnit.Case, async: true

  alias Quiver.Error.H3DatagramsDisabled

  test "is in the :transient class" do
    err = H3DatagramsDisabled.exception(origin: {:https, "example.test", 443})
    assert err.class == :transient
  end

  test "formats the origin in the message" do
    err = H3DatagramsDisabled.exception(origin: {:https, "example.test", 443})
    assert Exception.message(err) =~ "example.test"
    assert Exception.message(err) =~ "HTTP/3 datagrams"
  end
end
