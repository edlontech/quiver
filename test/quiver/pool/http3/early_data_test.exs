defmodule Quiver.Pool.HTTP3.EarlyDataTest do
  use ExUnit.Case, async: true

  alias Quiver.Pool.HTTP3.EarlyData

  describe "enabled?/1" do
    test "true only when pool config has early_data: true" do
      assert EarlyData.enabled?(early_data: true)
      refute EarlyData.enabled?(early_data: false)
      refute EarlyData.enabled?([])
    end
  end

  describe "eligible?/3" do
    test "false when the pool has early_data disabled, regardless of opts" do
      refute EarlyData.eligible?(:get, [], [])
      refute EarlyData.eligible?(:get, [early_data: true], [])
    end

    test "per-request early_data: false suppresses even safe methods" do
      refute EarlyData.eligible?(:get, [early_data: false], early_data: true)
    end

    test "per-request early_data: true forces, even for unsafe methods" do
      assert EarlyData.eligible?(:post, [early_data: true], early_data: true)
      assert EarlyData.eligible?(:delete, [early_data: true], early_data: true)
    end

    test "absent per-request opt defaults to safe methods only" do
      assert EarlyData.eligible?(:get, [], early_data: true)
      assert EarlyData.eligible?(:head, [], early_data: true)
      assert EarlyData.eligible?(:options, [], early_data: true)
      assert EarlyData.eligible?(:trace, [], early_data: true)
      refute EarlyData.eligible?(:post, [], early_data: true)
      refute EarlyData.eligible?(:put, [], early_data: true)
      refute EarlyData.eligible?(:delete, [], early_data: true)
    end
  end
end
