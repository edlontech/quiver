defmodule Quiver.TestCase.Integration do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      import Quiver.TestCase.Integration, only: [poll_until: 1, poll_until: 2]
    end
  end

  def poll_until(fun, timeout \\ 1_000) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_poll(fun, deadline)
  end

  defp do_poll(fun, deadline) do
    if fun.() do
      :ok
    else
      if System.monotonic_time(:millisecond) >= deadline do
        ExUnit.Assertions.flunk("condition not met within timeout")
      else
        Process.sleep(10)
        do_poll(fun, deadline)
      end
    end
  end
end
