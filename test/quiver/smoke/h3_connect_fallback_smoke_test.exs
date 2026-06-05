defmodule Quiver.Smoke.H3ConnectFallbackSmokeTest do
  @moduledoc """
  Verifies the pool worker's sequential connect fallback: when the first
  candidate address is unreachable, it dials the next one instead of failing.
  """
  use Quiver.SmokeCase, async: false

  alias Quiver.Pool.HTTP3.Connection

  # TEST-NET-1 (RFC 5737) - guaranteed unreachable, so the first attempt times out.
  @unreachable {192, 0, 2, 1}
  @loopback {127, 0, 0, 1}

  test "falls back to the next candidate when the first address is unreachable" do
    Process.flag(:trap_exit, true)

    {:ok, pid} =
      Connection.start_link(
        origin: {:https, "localhost", h3_port()},
        config: [verify: :verify_none, connect_timeout: 800],
        pool_pid: self(),
        connect_candidates: [@unreachable, @loopback]
      )

    assert_receive {:connection_ready, ^pid, max_streams}, 5_000
    assert max_streams > 0
  end

  test "fails cleanly once every candidate is exhausted" do
    Process.flag(:trap_exit, true)

    {:ok, pid} =
      Connection.start_link(
        origin: {:https, "localhost", h3_port()},
        config: [verify: :verify_none, connect_timeout: 500],
        pool_pid: self(),
        connect_candidates: [@unreachable]
      )

    refute_receive {:connection_ready, ^pid, _}, 1_500
    assert_receive {:EXIT, ^pid, :normal}, 2_000
  end
end
