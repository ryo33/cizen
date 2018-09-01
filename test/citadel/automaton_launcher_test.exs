defmodule Citadel.AutomatonLauncherTest do
  use ExUnit.Case
  doctest Citadel.AutomatonLauncher
  import Citadel.TestHelper, only: [launch_test_automaton: 0]
  alias Citadel.TestAutomaton
  alias Citadel.TestHelper

  import Citadel.Dispatcher, only: [dispatch: 1]
  alias Citadel.AutomatonID
  alias Citadel.AutomatonLauncher
  alias Citadel.AutomatonRegistry
  alias Citadel.Event

  test "AutomatonLauncher.LaunchAutomaton event" do
    pid = self()
    automaton_id = AutomatonID.new()

    dispatch(
      Event.new(%AutomatonLauncher.LaunchAutomaton{
        id: automaton_id,
        module: TestAutomaton,
        state: %{
          launch: fn id, _state ->
            send(pid, {:ok, id})
          end
        }
      })
    )

    assert_receive {:ok, automaton_id}

    TestHelper.ensure_finished(automaton_id)
  end

  test "AutomatonLauncher.UnlaunchAutomaton event" do
    id = launch_test_automaton()
    assert {:ok, pid} = AutomatonRegistry.resolve_id(id)
    dispatch(Event.new(%AutomatonLauncher.UnlaunchAutomaton{id: id}))
    :timer.sleep(50)
    refute Process.alive?(pid)
  end
end
