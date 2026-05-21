defmodule Quiver.Smoke.H3ConcurrencySmokeTest do
  use Quiver.SmokeCase, async: false

  alias Quiver.Pool.Manager

  setup do
    name = :"smoke_conc_#{System.unique_integer([:positive])}"

    start_supervised!(
      {Quiver.Supervisor,
       name: name,
       pools: %{
         default: [protocol: :http3, verify: :verify_none]
       }}
    )

    test_pid = self()
    handler_id = "smoke-conc-#{System.unique_integer([:positive])}"

    :telemetry.attach(
      handler_id,
      [:quiver, :request, :stop],
      fn _e, _m, _meta, _ -> send(test_pid, :req_stop) end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    {:ok, name: name}
  end

  test "50 concurrent GETs all succeed", %{name: name} do
    results =
      1..50
      |> Task.async_stream(
        fn _ ->
          Quiver.new(:get, h3_url("/test.txt"))
          |> Quiver.request(name: name, receive_timeout: 30_000)
        end,
        max_concurrency: 20,
        timeout: 30_000,
        ordered: false
      )
      |> Enum.to_list()

    statuses =
      for {:ok, {:ok, resp}} <- results, do: resp.status

    assert length(statuses) == 50
    assert Enum.all?(statuses, &(&1 == 200))

    origin = {:https, "localhost", h3_port()}
    assert {:ok, stats} = Manager.pool_stats(name, origin)
    assert stats.connections >= 1

    assert_n_messages(:req_stop, 50, 5_000)
  end

  defp assert_n_messages(_msg, 0, _timeout), do: :ok

  defp assert_n_messages(msg, n, timeout) do
    receive do
      ^msg -> assert_n_messages(msg, n - 1, timeout)
    after
      timeout -> flunk("only received #{50 - n} of 50 #{inspect(msg)} events within #{timeout}ms")
    end
  end
end
