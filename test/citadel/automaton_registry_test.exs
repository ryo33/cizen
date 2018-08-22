defmodule Citadel.AutomatonRegistryTest do
  use ExUnit.Case
  doctest Citadel.AutomatonRegistry
  import Citadel.TestHelper, only: [launch_test_automaton: 0]

  import Citadel.Dispatcher, only: [dispatch: 1]
  alias Citadel.AutomatonLauncher
  alias Citadel.AutomatonRegistry

  test "launched automaton is registered" do
    id = launch_test_automaton()
    assert {:ok, pid} = AutomatonRegistry.resolve_id(id)
  end

  test "killed automaton is unregistered" do
    id = launch_test_automaton()
    assert {:ok, pid} = AutomatonRegistry.resolve_id(id)
    true = Process.exit(pid, :kill)
    dispatch(%AutomatonLauncher.UnlaunchAutomaton{id: id})
    :timer.sleep(50)
    assert :error = AutomatonRegistry.resolve_id(id)
  end
end
