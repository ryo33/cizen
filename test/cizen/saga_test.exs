defmodule Cizen.SagaTest do
  use Cizen.SagaCase
  doctest Cizen.Saga

  alias Cizen.TestSaga

  import Cizen.TestHelper,
    only: [
      launch_test_saga: 0,
      launch_test_saga: 1,
      assert_condition: 2
    ]

  alias Cizen.CizenSagaRegistry
  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.Saga
  alias Cizen.SagaID
  alias Cizen.SagaLauncher

  alias Cizen.StartSaga

  describe "Saga" do
    test "dispatches Launched event on launch" do
      Dispatcher.listen_event_type(Saga.Launched)
      id = launch_test_saga()
      assert_receive %Event{body: %Saga.Launched{id: ^id}}
    end

    test "finishes on Finish event" do
      Dispatcher.listen_event_type(Saga.Launched)
      id = launch_test_saga()
      Dispatcher.dispatch(Event.new(nil, %Saga.Finish{id: id}))
      assert_condition(100, :error == CizenSagaRegistry.get_pid(id))
    end

    test "dispatches Finished event on finish" do
      Dispatcher.listen_event_type(Saga.Finished)
      id = launch_test_saga()
      Dispatcher.dispatch(Event.new(nil, %Saga.Finish{id: id}))
      assert_receive %Event{body: %Saga.Finished{id: ^id}}
    end

    test "dispatches Unlaunched event on unlaunch" do
      Dispatcher.listen_event_type(Saga.Unlaunched)
      id = launch_test_saga()
      Dispatcher.dispatch(Event.new(nil, %SagaLauncher.UnlaunchSaga{id: id}))
      assert_receive %Event{body: %Saga.Unlaunched{id: id}}
    end

    defmodule(CrashTestEvent1, do: defstruct([]))

    test "terminated on crash" do
      surpress_crash_log()

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

      Dispatcher.dispatch(Event.new(nil, %CrashTestEvent1{}))
      assert_condition(100, :error == CizenSagaRegistry.get_pid(id))
    end

    defmodule(CrashTestEvent2, do: defstruct([]))

    test "dispatches Crashed event on crash" do
      surpress_crash_log()

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

      Dispatcher.dispatch(Event.new(nil, %CrashTestEvent2{}))

      assert_receive %Event{
        body: %Saga.Crashed{
          id: ^id,
          reason: %RuntimeError{},
          stacktrace: [{__MODULE__, _, _, _} | _]
        }
      }
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
                Dispatcher.dispatch(Event.new(nil, %TestEventReply{value: value}))
                state

              _ ->
                state
            end
          end
        )

      Dispatcher.dispatch(Event.new(nil, %TestEvent{value: id}))
      assert_receive %Event{body: %TestEventReply{value: id}}
    end

    test "finishes immediately" do
      Dispatcher.listen_event_type(Saga.Finished)

      id =
        launch_test_saga(
          launch: fn id, state ->
            Dispatcher.dispatch(Event.new(nil, %Saga.Finish{id: id}))
            state
          end
        )

      assert_receive %Event{body: %Saga.Finished{id: ^id}}
      assert_condition(100, :error == CizenSagaRegistry.get_pid(id))
    end

    defmodule LazyLaunchSaga do
      @behaviour Cizen.Saga

      defstruct []

      @impl true
      def init(_, _) do
        Dispatcher.listen_event_type(TestEvent)
        {Saga.lazy_launch(), :ok}
      end

      @impl true
      def handle_event(id, %Event{body: %TestEvent{}}, :ok) do
        Dispatcher.dispatch(Event.new(nil, %Saga.Launched{id: id}))
        :ok
      end
    end

    test "does not dispatch Launched event on lazy launch" do
      Dispatcher.listen_event_type(Saga.Launched)
      id = SagaID.new()
      Saga.launch(id, %LazyLaunchSaga{})
      refute_receive %Event{body: %Saga.Launched{id: ^id}}
      Dispatcher.dispatch(Event.new(nil, %TestEvent{}))
      assert_receive %Event{body: %Saga.Launched{id: ^id}}
    end
  end

  describe "Saga.module/1" do
    test "returns the saga module" do
      assert Saga.module(%TestSaga{}) == TestSaga
    end
  end

  describe "Saga.start_link/2" do
    test "dispatches StartSaga event" do
      Dispatcher.listen_event_type(StartSaga)
      Saga.start_link(%TestSaga{extra: :some_value})
      assert_receive %Event{body: %StartSaga{saga: %TestSaga{extra: :some_value}}}
    end

    test "returns {:ok, saga_id}" do
      Dispatcher.listen_event_type(StartSaga)
      saga_id = Saga.start_link(%TestSaga{extra: :some_value})
      received = assert_receive %Event{body: %StartSaga{saga: %TestSaga{extra: :some_value}}}
      assert saga_id == received.body.id
    end
  end
end
