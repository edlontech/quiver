defmodule Quiver.StreamResponseTest do
  use ExUnit.Case, async: true

  alias Quiver.StreamResponse

  describe "struct" do
    test "enforces status, headers, body, ref" do
      ref = make_ref()
      stream = Stream.map(1..3, & &1)

      resp = %StreamResponse{
        status: 200,
        headers: [{"content-type", "text/plain"}],
        body: stream,
        ref: ref
      }

      assert resp.status == 200
      assert resp.headers == [{"content-type", "text/plain"}]
      assert Enum.to_list(resp.body) == [1, 2, 3]
      assert resp.ref == ref
    end
  end
end
