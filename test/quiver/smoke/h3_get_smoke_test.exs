defmodule Quiver.Smoke.H3GetSmokeTest do
  use Quiver.SmokeCase, async: false

  setup do
    name = :"smoke_get_#{System.unique_integer([:positive])}"

    start_supervised!(
      {Quiver.Supervisor,
       name: name,
       pools: %{
         default: [protocol: :http3, verify: :verify_none]
       }}
    )

    {:ok, name: name}
  end

  test "GET /test.txt returns the on-disk file", %{name: name} do
    expected = File.read!("docker/www/test.txt")

    assert {:ok, resp} =
             Quiver.new(:get, h3_url("/test.txt"))
             |> Quiver.request(name: name)

    assert resp.status == 200
    assert resp.body == expected
  end

  test "GET /large.bin streams 1 MiB and matches the on-disk fixture", %{name: name} do
    expected = File.read!("docker/www/large.bin")
    expected_hash = :crypto.hash(:sha256, expected)

    assert {:ok, resp} =
             Quiver.new(:get, h3_url("/large.bin"))
             |> Quiver.request(name: name, receive_timeout: 30_000)

    assert resp.status == 200
    assert byte_size(resp.body) == 1_048_576
    assert :crypto.hash(:sha256, resp.body) == expected_hash
  end

  test "HEAD /test.txt returns headers without a body", %{name: name} do
    assert {:ok, resp} =
             Quiver.new(:head, h3_url("/test.txt"))
             |> Quiver.request(name: name)

    assert resp.status == 200
    assert resp.body == ""
    assert is_binary(get_header(resp.headers, "content-length"))
  end

  test "GET /no-such-file returns 404 without raising", %{name: name} do
    assert {:ok, resp} =
             Quiver.new(:get, h3_url("/no-such-file"))
             |> Quiver.request(name: name)

    assert resp.status == 404
    assert byte_size(resp.body) > 0
  end
end
