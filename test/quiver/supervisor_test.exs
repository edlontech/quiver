defmodule Quiver.SupervisorTest do
  use ExUnit.Case, async: true

  describe "start_link/1" do
    test "starts a named supervisor with default config" do
      name = :"test_sup_#{System.unique_integer([:positive])}"
      assert {:ok, sup} = Quiver.Supervisor.start_link(name: name)
      assert Process.whereis(name) == sup

      assert Process.whereis(Quiver.Supervisor.registry_name(name)) |> is_pid()
      assert Process.whereis(Quiver.Supervisor.supervisor_name(name)) |> is_pid()

      rules = :persistent_term.get({Quiver.Pool.Manager, name, :rules})
      assert is_list(rules)

      Supervisor.stop(sup)
    end

    test "starts with custom pool config" do
      name = :"test_sup_#{System.unique_integer([:positive])}"

      assert {:ok, sup} =
               Quiver.Supervisor.start_link(
                 name: name,
                 pools: %{
                   "https://api.example.com" => [size: 25],
                   "https://*.example.com" => [size: 10],
                   :default => [size: 5]
                 }
               )

      rules = :persistent_term.get({Quiver.Pool.Manager, name, :rules})
      assert length(rules) == 3

      Supervisor.stop(sup)
    end

    test "defaults to Quiver.Pool when :name is omitted" do
      {:ok, sup} = Quiver.Supervisor.start_link([])
      assert Process.whereis(Quiver.Pool) == sup
      Supervisor.stop(sup)
    end

    test "crashes on invalid pool config" do
      name = :"test_sup_#{System.unique_integer([:positive])}"

      Process.flag(:trap_exit, true)

      assert {:error, {%Quiver.Error.InvalidPoolRule{}, _}} =
               Quiver.Supervisor.start_link(
                 name: name,
                 pools: %{"ftp://bad.com" => [size: 1]}
               )
    end

    test "crashes on invalid pool options in rule config" do
      name = :"test_sup_#{System.unique_integer([:positive])}"

      Process.flag(:trap_exit, true)

      assert {:error, {%Quiver.Error.InvalidPoolOpts{}, _}} =
               Quiver.Supervisor.start_link(
                 name: name,
                 pools: %{"https://api.example.com" => [size: -1]}
               )
    end

    test "multiple named instances coexist" do
      name1 = :"test_sup_#{System.unique_integer([:positive])}"
      name2 = :"test_sup_#{System.unique_integer([:positive])}"

      {:ok, sup1} = Quiver.Supervisor.start_link(name: name1, pools: %{:default => [size: 3]})
      {:ok, sup2} = Quiver.Supervisor.start_link(name: name2, pools: %{:default => [size: 7]})

      rules1 = :persistent_term.get({Quiver.Pool.Manager, name1, :rules})
      rules2 = :persistent_term.get({Quiver.Pool.Manager, name2, :rules})
      assert hd(rules1).config != hd(rules2).config

      Supervisor.stop(sup1)
      Supervisor.stop(sup2)
    end

    test "cleans up persistent_term on supervisor stop" do
      name = :"test_sup_#{System.unique_integer([:positive])}"
      {:ok, sup} = Quiver.Supervisor.start_link(name: name)

      assert :persistent_term.get({Quiver.Pool.Manager, name, :rules}) |> is_list()

      Supervisor.stop(sup)
      Process.sleep(50)

      assert_raise ArgumentError, fn ->
        :persistent_term.get({Quiver.Pool.Manager, name, :rules})
      end
    end
  end
end
