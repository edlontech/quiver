defmodule Quiver.Smoke.H3TrailersHeadSmokeTest do
  use Quiver.SmokeCase, async: false

  setup do
    name = :"smoke_trailers_#{System.unique_integer([:positive])}"

    start_supervised!(
      {Quiver.Supervisor,
       name: name,
       pools: %{
         default: [protocol: :http3, verify: :verify_none]
       }}
    )

    {:ok, name: name}
  end

  test "POST /trailers exposes server-emitted trailers on the response", %{name: name} do
    assert {:ok, resp} =
             Quiver.new(:post, h3_url("/trailers"))
             |> Quiver.body("payload")
             |> Quiver.request(name: name)

    assert resp.status == 200
    assert get_trailer(resp, "x-checksum") == "abc123"
    assert get_trailer(resp, "x-trailer-test") == "success"
  end
end
