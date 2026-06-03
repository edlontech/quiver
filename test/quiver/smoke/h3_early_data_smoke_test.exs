defmodule Quiver.Smoke.H3EarlyDataSmokeTest do
  use Quiver.SmokeCase, async: false

  setup do
    name = :"smoke_early_#{System.unique_integer([:positive])}"

    start_supervised!(
      {Quiver.Supervisor,
       name: name,
       pools: %{
         default: [protocol: :http3, early_data: true, verify: :verify_none]
       }}
    )

    {:ok, name: name}
  end

  test "an early-data pool serves requests and the third-party server issues tickets", %{
    name: name
  } do
    id = "smoke-ticket-#{System.unique_integer([:positive])}"
    test_pid = self()

    :ok =
      :telemetry.attach(
        id,
        [:quiver, :connection, :http3, :ticket_received],
        fn _evt, meas, meta, _ -> send(test_pid, {:ticket, meas, meta}) end,
        nil
      )

    on_exit(fn -> :telemetry.detach(id) end)

    assert {:ok, %{status: 200}} =
             Quiver.new(:get, h3_url("/test.txt")) |> Quiver.request(name: name)

    # aioquic, configured with a SessionTicketStore, issues a NewSessionTicket
    # which the worker captures and the coordinator caches.
    assert_receive {:ticket, %{lifetime: _, max_early_data: _}, %{origin: _}}, 5_000
  end

  test "early_data: false per-request still succeeds (graceful 1-RTT)", %{name: name} do
    assert {:ok, %{status: 200}} =
             Quiver.new(:get, h3_url("/test.txt"))
             |> Quiver.request(name: name, early_data: false)
  end
end
