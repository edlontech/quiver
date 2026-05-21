defmodule Quiver.Smoke.H3GoawaySmokeTest do
  use Quiver.SmokeCase, async: false

  alias Quiver.Error.H3GoAway
  alias Quiver.Response

  setup do
    name = :"smoke_goaway_#{System.unique_integer([:positive])}"

    start_supervised!(
      {Quiver.Supervisor,
       name: name,
       pools: %{
         default: [protocol: :http3, verify: :verify_none]
       }}
    )

    {:ok, name: name}
  end

  test "request following a GOAWAY-triggering request still succeeds", %{name: name} do
    res1 =
      Quiver.new(:get, h3_url("/goaway"))
      |> Quiver.request(name: name, receive_timeout: 2_000)

    case res1 do
      {:ok, %Response{status: 200}} -> :ok
      {:error, %H3GoAway{}} -> :ok
      other -> flunk("unexpected /goaway result: #{inspect(other)}")
    end

    Process.sleep(50)

    assert {:ok, resp2} =
             Quiver.new(:get, h3_url("/test.txt"))
             |> Quiver.request(name: name)

    assert resp2.status == 200
    assert resp2.body == File.read!("docker/www/test.txt")
  end
end
