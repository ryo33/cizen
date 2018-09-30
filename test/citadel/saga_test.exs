defmodule Citadel.SagaTest do
  use ExUnit.Case
  doctest Citadel.Saga

  import Citadel.TestHelper,
    only: [
      launch_test_saga: 0,
      launch_test_saga: 1,
      assert_condition: 2
    ]

  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.Saga
  alias Citadel.SagaLauncher
  alias Citadel.SagaRegistry

  test "dispatches Launched event on launch" do
    Dispatcher.listen_event_type(Saga.Launched)
    id = launch_test_saga()
    assert_receive %Event{body: %Saga.Launched{id: ^id}}
  end

  test "finishes on Finish event" do
    Dispatcher.listen_event_type(Saga.Launched)
    id = launch_test_saga()
    Dispatcher.dispatch(Event.new(%Saga.Finish{id: id}))
    assert_condition(100, :error == SagaRegistry.resolve_id(id))
  end

  test "dispatches Finished event on finish" do
    Dispatcher.listen_event_type(Saga.Finished)
    id = launch_test_saga()
    Dispatcher.dispatch(Event.new(%Saga.Finish{id: id}))
    assert_receive %Event{body: %Saga.Finished{id: ^id}}
  end

  test "dispatches Unlaunched event on unlaunch" do
    Dispatcher.listen_event_type(Saga.Unlaunched)
    id = launch_test_saga()
    Dispatcher.dispatch(Event.new(%SagaLauncher.UnlaunchSaga{id: id}))
    assert_receive %Event{body: %Saga.Unlaunched{id: id}}
  end

  defmodule(CrashTestEvent1, do: defstruct([]))

  test "terminated on crash" do
    id =
      launch_test_saga(
        launch: fn _id, _state ->
          Dispatcher.listen_event_type(CrashTestEvent1)
        end,
        handle_event: fn _id, %Event{body: body}, state ->
          case body do
            %CrashTestEvent1{} ->
              raise "Crash!!!"

            _ ->
              state
          end
        end
      )

    Dispatcher.dispatch(Event.new(%CrashTestEvent1{}))
    assert_condition(100, :error == SagaRegistry.resolve_id(id))
  end

  defmodule(CrashTestEvent2, do: defstruct([]))

  test "dispatches Crashed event on crash" do
    Dispatcher.listen_event_type(Saga.Crashed)

    id =
      launch_test_saga(
        launch: fn _id, _state ->
          Dispatcher.listen_event_type(CrashTestEvent2)
        end,
        handle_event: fn _id, %Event{body: body}, state ->
          case body do
            %CrashTestEvent2{} ->
              raise "Crash!!!"

            _ ->
              state
          end
        end
      )

    Dispatcher.dispatch(Event.new(%CrashTestEvent2{}))
    assert_receive %Event{body: %Saga.Crashed{id: ^id, reason: %RuntimeError{}}}
  end

  defmodule(TestEvent, do: defstruct([:value]))
  defmodule(TestEventReply, do: defstruct([:value]))

  test "handles events" do
    Dispatcher.listen_event_type(TestEventReply)

    id =
      launch_test_saga(
        launch: fn _id, _state ->
          Dispatcher.listen_event_type(TestEvent)
        end,
        handle_event: fn _id, %Event{body: body}, state ->
          case body do
            %TestEvent{value: value} ->
              Dispatcher.dispatch(Event.new(%TestEventReply{value: value}))
              state

            _ ->
              state
          end
        end
      )

    Dispatcher.dispatch(Event.new(%TestEvent{value: id}))
    assert_receive %Event{body: %TestEventReply{value: id}}
  end

  test "finishes immediately" do
    Dispatcher.listen_event_type(Saga.Finished)

    id =
      launch_test_saga(
        launch: fn id, state ->
          Dispatcher.dispatch(Event.new(%Saga.Finish{id: id}))
          state
        end
      )

    assert_receive %Event{body: %Saga.Finished{id: ^id}}
    assert_condition(100, :error == SagaRegistry.resolve_id(id))
  end
end
