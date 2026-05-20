defmodule Quiver.Error.H3CodesTest do
  use ExUnit.Case, async: true

  alias Quiver.Error.H3Codes

  test "decodes known codes" do
    assert :h3_no_error = H3Codes.decode(0x100)
    assert :h3_request_cancelled = H3Codes.decode(0x10C)
    assert :h3_version_fallback = H3Codes.decode(0x110)
  end

  test "returns :unknown for unmapped codes" do
    assert {:unknown, 0x999} = H3Codes.decode(0x999)
  end

  test "list/0 returns all known codes" do
    list = H3Codes.list()
    assert length(list) == 17
    assert Enum.all?(list, fn {c, a} -> is_integer(c) and is_atom(a) end)
  end
end
