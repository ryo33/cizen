defmodule Citadel.TestHelper do
  @moduledoc false
  import ExUnit.Assertions, only: [flunk: 0]
  import ExUnit.Callbacks, only: [on_exit: 1]
  import Citadel.Dispatcher, only: [listen_event_type: 1, dispatch: 1]
  alias Citadel.Automaton
  alias Citadel.AutomatonID
  alias Citadel.AutomatonLauncher
  alias Citadel.AutomatonRegistry
  alias Citadel.Event
  alias Citadel.TestAutomaton

  def ensure_finished(id) do
    case AutomatonRegistry.resolve_id(id) do
      {:ok, _pid} ->
        listen_event_type(Automaton.Finished)
        dispatch(Event.new(%Automaton.Finish{id: id}))

        receive do
          %Event{body: %Automaton.Finished{id: ^id}} -> :ok
        after
          50 -> :ok
        end

      :error ->
        :ok
    end
  end

  def launch_test_automaton(opts \\ []) do
    pid = self()
    automaton_id = AutomatonID.new()

    dispatch(
      Event.new(%AutomatonLauncher.LaunchAutomaton{
        id: automaton_id,
        module: TestAutomaton,
        state: %{
          launch: fn id, state ->
            launch = Keyword.get(opts, :launch, fn _id, state -> state end)
            state = launch.(id, state)
            send(pid, {:ok, id})
            state
          end,
          yield: Keyword.get(opts, :yield, fn _id, _event, state -> state end)
        }
      })
    )

    receive do
      {:ok, ^automaton_id} -> :ok
    after
      50 -> flunk()
    end

    on_exit(fn ->
      ensure_finished(automaton_id)
    end)

    automaton_id
  end
end
