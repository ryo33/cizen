defmodule Citadel.TestHelper do
  @moduledoc false
  import Citadel.Dispatcher, only: [dispatch: 1]
  alias Citadel.AutomatonID
  alias Citadel.AutomatonLauncher
  alias Citadel.Event
  alias Citadel.TestAutomaton

  def launch_test_automaton do
    pid = self()
    automaton_id = AutomatonID.new()

    dispatch(
      Event.new(%AutomatonLauncher.LaunchAutomaton{
        id: automaton_id,
        module: TestAutomaton,
        state: fn id ->
          send(pid, {:ok, id})
        end
      })
    )

    receive do
      {:ok, ^automaton_id} -> :ok
    end

    automaton_id
  end
end
