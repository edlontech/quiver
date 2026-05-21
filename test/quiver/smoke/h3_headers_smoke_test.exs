defmodule Quiver.Smoke.H3HeadersSmokeTest do
  use Quiver.SmokeCase, async: false

  setup do
    name = :"smoke_headers_#{System.unique_integer([:positive])}"

    start_supervised!(
      {Quiver.Supervisor,
       name: name,
       pools: %{
         default: [protocol: :http3, verify: :verify_none]
       }}
    )

    test_pid = self()
    handler_id = "smoke-headers-#{System.unique_integer([:positive])}"

    :telemetry.attach(
      handler_id,
      [:quiver, :connection, :http3, :exception],
      fn _e, _m, meta, _ -> send(test_pid, {:h3_exception, meta}) end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    {:ok, name: name}
  end

  test "30 requests with rolling distinct headers all succeed (QPACK churn)", %{name: name} do
    results =
      for i <- 1..30 do
        Quiver.new(:get, h3_url("/test.txt"))
        |> Quiver.header("x-trace-id", "trace-#{System.unique_integer([:positive])}")
        |> Quiver.header("x-bucket-#{rem(i, 7)}", "value-#{i}")
        |> Quiver.request(name: name)
      end

    statuses = for {:ok, resp} <- results, do: resp.status
    assert length(statuses) == 30
    assert Enum.all?(statuses, &(&1 == 200))

    refute_receive {:h3_exception, _}, 0
  end
end
