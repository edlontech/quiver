defmodule Quiver.Smoke.H3PostSmokeTest do
  use Quiver.SmokeCase, async: false

  setup do
    name = :"smoke_post_#{System.unique_integer([:positive])}"

    start_supervised!(
      {Quiver.Supervisor,
       name: name,
       pools: %{
         default: [protocol: :http3, verify: :verify_none]
       }}
    )

    {:ok, name: name}
  end

  test "POST /echo with 1 KiB body round-trips", %{name: name} do
    body = :binary.copy("a", 1_024)

    assert {:ok, resp} =
             Quiver.new(:post, h3_url("/echo"))
             |> Quiver.body(body)
             |> Quiver.request(name: name)

    assert resp.status == 200
    assert resp.body == body
  end

  # 256 KiB instead of 1 MiB (and below): aioquic default max_data limits a single
  # POST to under 1 MiB; see commit 608294b. Fragmentation across DATA frames is
  # still meaningfully exercised at this size.
  test "POST /echo with a large fixed body round-trips", %{name: name} do
    body = :crypto.strong_rand_bytes(256 * 1024)

    assert {:ok, resp} =
             Quiver.new(:post, h3_url("/echo"))
             |> Quiver.body(body)
             |> Quiver.request(name: name, receive_timeout: 30_000)

    assert resp.status == 200
    assert resp.body == body
  end

  test "POST /echo with a streamed body round-trips", %{name: name} do
    chunks = for _ <- 1..4, do: :crypto.strong_rand_bytes(64 * 1024)
    expected = IO.iodata_to_binary(chunks)

    assert {:ok, resp} =
             Quiver.new(:post, h3_url("/echo"))
             |> Quiver.stream_body(chunks)
             |> Quiver.request(name: name, receive_timeout: 30_000)

    assert resp.status == 200
    assert resp.body == expected
  end
end
