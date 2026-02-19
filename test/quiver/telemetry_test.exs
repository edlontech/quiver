defmodule Quiver.TelemetryTest do
  use ExUnit.Case, async: true

  alias Quiver.Telemetry

  def handle_telemetry(event, measurements, metadata, pid) do
    send(pid, {event, measurements, metadata})
  end

  describe "event name constants" do
    test "request_event_prefix" do
      assert Telemetry.request_event_prefix() == [:quiver, :request]
    end

    test "conn_event_prefix" do
      assert Telemetry.conn_event_prefix() == [:quiver, :conn]
    end

    test "conn_close_event" do
      assert Telemetry.conn_close_event() == [:quiver, :conn, :close]
    end

    test "pool_queue_event" do
      assert Telemetry.pool_queue_event() == [:quiver, :pool, :queue]
    end
  end

  describe "span/3" do
    test "emits start and stop events with metadata" do
      ref = make_ref()
      parent = self()

      :telemetry.attach_many(
        "span-#{inspect(ref)}",
        [[:quiver, :request, :start], [:quiver, :request, :stop]],
        &__MODULE__.handle_telemetry/4,
        parent
      )

      result =
        Telemetry.span([:quiver, :request], %{request: :test}, fn ->
          {:the_result, %{response: :test}}
        end)

      assert result == :the_result

      assert_received {[:quiver, :request, :start], %{system_time: _},
                       %{request: :test, telemetry_span_context: _}}

      assert_received {[:quiver, :request, :stop], %{duration: _},
                       %{response: :test, telemetry_span_context: _}}

      :telemetry.detach("span-#{inspect(ref)}")
    end
  end

  describe "event/3" do
    test "emits a standalone event" do
      ref = make_ref()
      parent = self()

      :telemetry.attach(
        "event-#{inspect(ref)}",
        [:quiver, :conn, :close],
        &__MODULE__.handle_telemetry/4,
        parent
      )

      Telemetry.event([:quiver, :conn, :close], %{system_time: 123}, %{origin: :test})

      assert_received {[:quiver, :conn, :close], %{system_time: 123}, %{origin: :test}}

      :telemetry.detach("event-#{inspect(ref)}")
    end
  end
end
