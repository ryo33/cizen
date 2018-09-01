defmodule Citadel.AutomatonTest do
  use ExUnit.Case
  doctest Citadel.Automaton

  import Citadel.TestHelper, only: [launch_test_automaton: 0, launch_test_automaton: 1]

  import Citadel.Dispatcher, only: [listen_event_type: 1, dispatch: 1]
  alias Citadel.Automaton
  alias Citadel.AutomatonLauncher
  alias Citadel.AutomatonRegistry
  alias Citadel.Event

  test "dispatches Launched event on launch" do
    listen_event_type(Automaton.Launched)
    id = launch_test_automaton()
    assert_receive %Event{body: %Automaton.Launched{id: ^id}}
  end

  test "finishes on Finish event" do
    listen_event_type(Automaton.Launched)
    id = launch_test_automaton()
    dispatch(Event.new(%Automaton.Finish{id: id}))
    :timer.sleep(100)
    assert :error = AutomatonRegistry.resolve_id(id)
  end

  test "dispatches Finished event on finish" do
    listen_event_type(Automaton.Finished)
    id = launch_test_automaton()
    dispatch(Event.new(%Automaton.Finish{id: id}))
    assert_receive %Event{body: %Automaton.Finished{id: ^id}}
  end

  test "dispatches Unlaunched event on unlaunch" do
    listen_event_type(Automaton.Unlaunched)
    id = launch_test_automaton()
    dispatch(Event.new(%AutomatonLauncher.UnlaunchAutomaton{id: id}))
    assert_receive %Event{body: %Automaton.Unlaunched{id: id}}
  end

  defmodule(CrashTestEvent1, do: defstruct([]))

  test "terminated on crash" do
    id =
      launch_test_automaton(
        launch: fn _id, _state ->
          listen_event_type(CrashTestEvent1)
        end,
        yield: fn _id, %Event{body: body}, state ->
          case body do
            %CrashTestEvent1{} ->
              raise "Crash!!!"

            _ ->
              state
          end
        end
      )

    dispatch(Event.new(%CrashTestEvent1{}))
    :timer.sleep(100)
    assert :error = AutomatonRegistry.resolve_id(id)
  end

  defmodule(CrashTestEvent2, do: defstruct([]))

  test "dispatches Crashed event on crash" do
    listen_event_type(Automaton.Crashed)

    id =
      launch_test_automaton(
        launch: fn _id, _state ->
          listen_event_type(CrashTestEvent2)
        end,
        yield: fn _id, %Event{body: body}, state ->
          case body do
            %CrashTestEvent2{} ->
              raise "Crash!!!"

            _ ->
              state
          end
        end
      )

    dispatch(Event.new(%CrashTestEvent2{}))
    assert_receive %Event{body: %Automaton.Crashed{id: ^id}}
  end

  defmodule(TestEvent, do: defstruct([:value]))
  defmodule(TestEventReply, do: defstruct([:value]))

  test "handles events" do
    listen_event_type(TestEventReply)

    id =
      launch_test_automaton(
        launch: fn _id, _state ->
          listen_event_type(TestEvent)
        end,
        yield: fn _id, %Event{body: body}, state ->
          case body do
            %TestEvent{value: value} ->
              dispatch(Event.new(%TestEventReply{value: value}))
              state

            _ ->
              state
          end
        end
      )

    dispatch(Event.new(%TestEvent{value: id}))
    assert_receive %Event{body: %TestEventReply{value: id}}
  end
end
