defmodule Cizen.SagaTest do
  use Cizen.SagaCase
  doctest Cizen.Saga

  alias Cizen.TestHelper
  alias Cizen.TestSaga

  import Cizen.TestHelper,
    only: [
      launch_test_saga: 0,
      launch_test_saga: 1,
      assert_condition: 2
    ]

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.Saga
  alias Cizen.SagaID
  alias Cizen.SagaLauncher

  defmodule(TestEvent, do: defstruct([:value]))

  describe "Saga" do
    test "dispatches Launched event on launch" do
      Dispatcher.listen_event_type(Saga.Started)
      id = launch_test_saga()
      assert_receive %Event{body: %Saga.Started{id: ^id}}
    end

    test "finishes on Finish event" do
      Dispatcher.listen_event_type(Saga.Started)
      id = launch_test_saga()
      Dispatcher.dispatch(Event.new(nil, %Saga.Finish{id: id}))
      assert_condition(100, :error == Saga.get_pid(id))
    end

    test "dispatches Finished event on finish" do
      Dispatcher.listen_event_type(Saga.Finished)
      id = launch_test_saga()
      Dispatcher.dispatch(Event.new(nil, %Saga.Finish{id: id}))
      assert_receive %Event{body: %Saga.Finished{id: ^id}}
    end

    test "dispatches Unlaunched event on unlaunch" do
      Dispatcher.listen_event_type(Saga.Ended)
      id = launch_test_saga()
      Dispatcher.dispatch(Event.new(nil, %SagaLauncher.UnlaunchSaga{id: id}))
      assert_receive %Event{body: %Saga.Ended{id: id}}
    end

    defmodule(CrashTestEvent1, do: defstruct([]))

    test "terminated on crash" do
      TestHelper.surpress_crash_log()

      id =
        launch_test_saga(
          init: fn _id, _state ->
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
      assert_condition(100, :error == Saga.get_pid(id))
    end

    defmodule(CrashTestEvent2, do: defstruct([]))

    test "dispatches Crashed event on crash" do
      TestHelper.surpress_crash_log()

      Dispatcher.listen_event_type(Saga.Crashed)

      id =
        launch_test_saga(
          init: fn _id, _state ->
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

    defmodule(TestEventReply, do: defstruct([:value]))

    test "handles events" do
      Dispatcher.listen_event_type(TestEventReply)

      id =
        launch_test_saga(
          init: fn _id, _state ->
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
          init: fn id, state ->
            Dispatcher.dispatch(Event.new(nil, %Saga.Finish{id: id}))
            state
          end
        )

      assert_receive %Event{body: %Saga.Finished{id: ^id}}
      assert_condition(100, :error == Saga.get_pid(id))
    end

    defmodule LazyLaunchSaga do
      use Cizen.Saga

      defstruct []

      @impl true
      def init(_, _) do
        Dispatcher.listen_event_type(TestEvent)
        {Saga.lazy_launch(), :ok}
      end

      @impl true
      def handle_event(id, %Event{body: %TestEvent{}}, :ok) do
        Dispatcher.dispatch(Event.new(nil, %Saga.Started{id: id}))
        :ok
      end
    end

    test "does not dispatch Launched event on lazy launch" do
      Dispatcher.listen_event_type(Saga.Started)
      id = SagaID.new()
      Saga.start_saga(id, %LazyLaunchSaga{}, nil)
      refute_receive %Event{body: %Saga.Started{id: ^id}}
      Dispatcher.dispatch(Event.new(nil, %TestEvent{}))
      assert_receive %Event{body: %Saga.Started{id: ^id}}
    end
  end

  describe "Saga.module/1" do
    test "returns the saga module" do
      assert Saga.module(%TestSaga{}) == TestSaga
    end
  end

  describe "Saga.fork/2" do
    test "starts a saga" do
      Dispatcher.listen_event_type(Saga.Started)
      Saga.fork(%TestSaga{extra: :some_value})
      assert_receive %Event{body: %Saga.Started{}}
    end

    test "returns saga_id" do
      Dispatcher.listen_event_type(Saga.Started)
      saga_id = Saga.fork(%TestSaga{extra: :some_value})
      received = assert_receive %Event{body: %Saga.Started{}}
      assert saga_id == received.body.id
    end

    test "finishes when the given lifetime process exits" do
      pid = self()

      process =
        spawn(fn ->
          saga_id = Saga.fork(%TestSaga{extra: :some_value})
          send(pid, saga_id)

          receive do
            :finish -> :ok
          end
        end)

      saga_id =
        receive do
          saga_id -> saga_id
        after
          1000 -> flunk("timeout")
        end

      assert {:ok, _} = Saga.get_pid(saga_id)

      send(process, :finish)

      assert_condition(100, :error == Saga.get_pid(saga_id))
    end
  end

  describe "Saga.start_link/2" do
    test "starts a saga" do
      Dispatcher.listen_event_type(Saga.Started)
      {:ok, pid} = Saga.start_link(%TestSaga{extra: :some_value})

      received =
        assert_receive %Event{body: %Saga.Started{}, source_saga: %TestSaga{extra: :some_value}}

      assert {:ok, ^pid} = Saga.get_pid(received.body.id)
    end

    test "starts a saga linked to the current process" do
      test_pid = self()

      current =
        spawn(fn ->
          {:ok, pid} = Saga.start_link(%TestSaga{extra: :some_value})
          send(test_pid, {:started, pid})

          receive do
            _ -> :ok
          end
        end)

      pid =
        receive do
          {:started, pid} -> pid
        after
          1000 -> flunk("timeout")
        end

      Process.exit(current, :kill)

      assert_condition(100, false == Process.alive?(pid))
    end
  end

  describe "Saga.get_pid/1" do
    test "launched saga is registered" do
      id = launch_test_saga()
      assert {:ok, pid} = Saga.get_pid(id)
    end

    test "killed saga is unregistered" do
      id = launch_test_saga()
      assert {:ok, pid} = Saga.get_pid(id)
      true = Process.exit(pid, :kill)
      assert_condition(100, :error == Saga.get_pid(id))
    end
  end

  defmodule TestSagaState do
    use Cizen.Saga
    defstruct [:value]
    @impl true
    def init(_id, %__MODULE__{}) do
      :ok
    end

    @impl true
    def handle_event(_id, _event, :ok) do
      :ok
    end
  end

  describe "Saga.get_saga/1" do
    test "returns a saga struct" do
      assert_handle(fn id ->
        use Cizen.Effects

        id =
          perform id, %Start{
            saga: %TestSagaState{value: :some_value}
          }

        assert {:ok, %TestSagaState{value: :some_value}} = Saga.get_saga(id)
      end)
    end

    test "returns error for unregistered saga" do
      assert :error == Saga.get_saga(SagaID.new())
    end
  end

  describe "Saga.send_to/2" do
    test "sends an event to a saga" do
      pid = self()

      id =
        launch_test_saga(
          handle_event: fn id, event, _state ->
            send(pid, {id, event})
          end
        )

      Saga.send_to(id, Event.new(nil, %TestEvent{value: 10}))
      assert_receive {^id, %Event{body: %TestEvent{value: 10}}}
    end
  end

  describe "Saga.resume/3" do
    test "starts a saga" do
      saga_id = SagaID.new()
      {:ok, pid} = Saga.resume(saga_id, %TestSaga{}, nil)

      assert {:ok, ^pid} = Saga.get_pid(saga_id)
    end

    test "does not invoke init callback" do
      pid = self()
      saga_id = SagaID.new()

      {:ok, _pid} =
        Saga.resume(
          saga_id,
          %TestSaga{
            init: fn _id, _saga ->
              send(pid, :called_init)
            end
          },
          nil
        )

      refute_receive :called_init
    end

    test "invokes resume callback with arguments" do
      pid = self()
      saga_id = SagaID.new()

      {:ok, _pid} =
        Saga.resume(
          saga_id,
          %TestSaga{
            resume: fn id, saga, state ->
              send(pid, {id, saga, state})
            end,
            extra: 42
          },
          :state
        )

      assert_receive {^saga_id, %TestSaga{extra: 42}, :state}
    end

    test "uses a resume callback's result as the next state" do
      pid = self()
      saga_id = SagaID.new()

      {:ok, _pid} =
        Saga.resume(
          saga_id,
          %TestSaga{
            resume: fn _id, _saga, _state ->
              :next_state
            end,
            handle_event: fn _id, _event, state ->
              send(pid, state)
            end
          },
          nil
        )

      Saga.send_to(saga_id, Event.new(nil, %TestEvent{}))

      assert_receive :next_state
    end

    defmodule TestSagaNoResume do
      use Saga
      defstruct [:value]

      @impl true
      def init(id, saga) do
        Dispatcher.dispatch(Event.new(id, %TestEvent{value: {:called_init, saga}}))
        :state
      end

      @impl true
      def handle_event(id, event, state) do
        Dispatcher.dispatch(
          Event.new(id, %TestEvent{value: {:called_handle_event, event, state}})
        )

        :next_state
      end
    end

    test "invokes init instead of resume when resume is not defined" do
      saga_id = SagaID.new()
      saga = %TestSagaNoResume{value: :some_value}
      Dispatcher.listen_event_type(TestEvent)

      {:ok, _pid} =
        Saga.resume(
          saga_id,
          saga,
          nil
        )

      assert_receive %Event{
        source_saga_id: ^saga_id,
        body: %TestEvent{value: {:called_init, ^saga}}
      }
    end

    test "use the given state as next state" do
      saga_id = SagaID.new()
      Dispatcher.listen_event_type(TestEvent)

      {:ok, _pid} =
        Saga.resume(
          saga_id,
          %TestSagaNoResume{},
          :resumed_state
        )

      receive do
        %Event{source_saga_id: ^saga_id, body: %TestEvent{value: {:called_init, _}}} -> :ok
      end

      event = Event.new(nil, %TestEvent{value: :some_value})
      Saga.send_to(saga_id, event)

      assert_receive %Event{
        source_saga_id: ^saga_id,
        body: %TestEvent{value: {:called_handle_event, ^event, :resumed_state}}
      }
    end
  end
end
