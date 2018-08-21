defmodule Citadel.AutomatonLauncherTest do
  use ExUnit.Case
  doctest Citadel

  import Citadel.Dispatcher, only: [dispatch: 1]
  alias Citadel.AutomatonID
  alias Citadel.AutomatonLauncher

  defmodule TestAutomaton do
    @behaviour Citadel.Automaton
    @impl Citadel.Automaton
    def launch(id, func), do: Task.start_link(fn -> func.(id) end)
  end

  test "AutomatonLauncher.Launch event" do
    pid = self()
    automaton_id = AutomatonID.new()

    dispatch(%AutomatonLauncher.Launch{
      id: automaton_id,
      module: TestAutomaton,
      state: fn id ->
        send(pid, {:ok, id})
      end
    })

    assert_receive {:ok, automaton_id}
  end
end
