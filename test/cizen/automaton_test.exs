defmodule Cizen.AutomatonTest do
  use Cizen.SagaCase
  alias Cizen.EffectHandlerTestHelper.{TestEffect, TestEvent}
  alias Cizen.TestHelper

  alias Cizen.Automaton
  alias Cizen.CizenSagaRegistry
  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.EventFilter
  alias Cizen.Messenger
  alias Cizen.Saga
  alias Cizen.SagaID

  alias Cizen.Automaton.PerformEffect
  alias Cizen.StartSaga

  describe "perform/2" do
    test "dispatches PerformEffect event" do
      import Automaton, only: [perform: 2]

      Dispatcher.listen_event_type(PerformEffect)
      saga_id = TestHelper.launch_test_saga()
      effect = %TestEffect{value: :a}

      spawn_link(fn ->
        perform(saga_id, effect)
      end)

      assert_receive %Event{body: %PerformEffect{effect: ^effect}, source_saga_id: ^saga_id}
    end

    test "block until message is coming and returns the message" do
      import Automaton, only: [perform: 2]
      current = self()
      saga_id = TestHelper.launch_test_saga()

      pid =
        spawn_link(fn ->
          assert :value == perform(saga_id, %TestEffect{value: :a})
          send(current, :ok)
        end)

      refute_receive :ok
      send(pid, :value)
      assert_receive :ok
    end
  end

  describe "Automaton" do
    defmodule TestAutomatonNotFinish do
      use Automaton

      defstruct []

      @impl true
      def spawn(_id, state) do
        state
      end

      @impl true
      def yield(_id, state) do
        :timer.sleep(100)
        state
      end
    end

    test "does not finishes" do
      saga_id = SagaID.new()
      Dispatcher.listen_event_body(%Saga.Finish{id: saga_id})

      Dispatcher.dispatch(
        Event.new(nil, %StartSaga{
          id: saga_id,
          saga: %TestAutomatonNotFinish{}
        })
      )

      refute_receive %Event{body: %Saga.Finish{id: ^saga_id}}
    end

    defmodule TestAutomatonFinishOnYield do
      use Automaton

      defstruct []

      @impl true
      def yield(_id, %__MODULE__{}) do
        :next
      end

      def yield(_id, :next) do
        Automaton.finish()
      end
    end

    test "finishes when yields Automaton.finish()" do
      saga_id = SagaID.new()
      Dispatcher.listen_event_body(%Saga.Finish{id: saga_id})

      Dispatcher.dispatch(
        Event.new(nil, %StartSaga{
          id: saga_id,
          saga: %TestAutomatonFinishOnYield{}
        })
      )

      assert_receive %Event{body: %Saga.Finish{id: ^saga_id}}
    end

    defmodule TestAutomatonFinishOnSpawn do
      use Automaton

      defstruct []

      @impl true
      def spawn(_id, %__MODULE__{}) do
        Automaton.finish()
      end

      @impl true
      def yield(_id, _state), do: :ok
    end

    test "finishes when spawn/2 returns Automaton.finish()" do
      saga_id = SagaID.new()
      Dispatcher.listen_event_body(%Saga.Finish{id: saga_id})

      Dispatcher.dispatch(
        Event.new(nil, %StartSaga{
          id: saga_id,
          saga: %TestAutomatonFinishOnSpawn{}
        })
      )

      assert_receive %Event{body: %Saga.Finish{id: ^saga_id}}
    end

    defmodule TestAutomaton do
      use Automaton

      defstruct [:pid]

      @impl true
      def spawn(id, %__MODULE__{pid: pid}) do
        Messenger.subscribe_message(id, %EventFilter{
          event_type: TestEvent
        })

        send(pid, :launched)
        send(pid, perform(id, %TestEffect{value: :a}))
        {:b, pid}
      end

      @impl true
      def yield(id, {:b, pid}) do
        send(pid, perform(id, %TestEffect{value: :b}))
        {:c, pid}
      end

      def yield(id, {:c, pid}) do
        send(pid, perform(id, %TestEffect{value: :c}))
        Automaton.finish()
      end
    end

    test "works with perform" do
      saga_id = SagaID.new()
      Dispatcher.listen_event_body(%Saga.Finish{id: saga_id})

      Dispatcher.dispatch(
        Event.new(nil, %StartSaga{
          id: saga_id,
          saga: %TestAutomaton{pid: self()}
        })
      )

      assert_receive :launched

      Dispatcher.dispatch(
        Event.new(nil, %TestEvent{
          value: :a,
          count: 1
        })
      )

      assert_receive {:a, 1}

      Dispatcher.dispatch(
        Event.new(nil, %TestEvent{
          value: :c,
          count: 2
        })
      )

      Dispatcher.dispatch(
        Event.new(nil, %TestEvent{
          value: :b,
          count: 1
        })
      )

      assert_receive {:b, 1}

      Dispatcher.dispatch(
        Event.new(nil, %TestEvent{
          value: :c,
          count: 3
        })
      )

      Dispatcher.dispatch(
        Event.new(nil, %TestEvent{
          value: :c,
          count: 3
        })
      )

      assert_receive {:c, 3}

      assert_receive %Event{body: %Saga.Finish{id: ^saga_id}}
    end

    test "dispatches Saga.Started event after spawn/2" do
      saga_id = SagaID.new()
      Dispatcher.listen_event_body(%Saga.Finish{id: saga_id})
      Dispatcher.listen_event_body(%Saga.Started{id: saga_id})

      Dispatcher.dispatch(
        Event.new(nil, %StartSaga{
          id: saga_id,
          saga: %TestAutomaton{pid: self()}
        })
      )

      assert_receive :launched

      refute_receive %Event{
        body: %Saga.Started{id: ^saga_id}
      }

      Dispatcher.dispatch(
        Event.new(nil, %TestEvent{
          value: :a,
          count: 1
        })
      )

      assert_receive %Event{
        body: %Saga.Started{id: ^saga_id}
      }
    end

    defmodule TestAutomatonNoSpawn do
      use Automaton

      defstruct [:pid]

      @impl true

      def yield(_id, %__MODULE__{pid: pid}) do
        send(pid, :called)
        Automaton.finish()
      end
    end

    test "works with no spawn/2" do
      saga_id = SagaID.new()
      Dispatcher.listen_event_body(%Saga.Finish{id: saga_id})
      Dispatcher.listen_event_body(%Saga.Started{id: saga_id})

      Dispatcher.dispatch(
        Event.new(nil, %StartSaga{
          id: saga_id,
          saga: %TestAutomatonNoSpawn{pid: self()}
        })
      )

      assert_receive %Event{
        body: %Saga.Finish{id: ^saga_id}
      }

      assert_receive :called

      assert_receive %Event{
        body: %Saga.Started{id: ^saga_id}
      }
    end

    defmodule TestAutomatonNoYield do
      use Automaton

      defstruct [:pid]

      @impl true

      def spawn(_id, %__MODULE__{pid: pid}) do
        send(pid, :called)
        Automaton.finish()
      end
    end

    test "works with no yield/2" do
      saga_id = SagaID.new()
      Dispatcher.listen_event_body(%Saga.Finish{id: saga_id})
      Dispatcher.listen_event_body(%Saga.Started{id: saga_id})

      Dispatcher.dispatch(
        Event.new(nil, %StartSaga{
          id: saga_id,
          saga: %TestAutomatonNoYield{pid: self()}
        })
      )

      assert_receive :called

      assert_receive %Event{
        body: %Saga.Finish{id: ^saga_id}
      }

      assert_receive %Event{
        body: %Saga.Started{id: ^saga_id}
      }
    end

    defmodule TestAutomatonCrash do
      use Automaton

      defstruct []

      @impl true

      def spawn(_id, %__MODULE__{}) do
        raise "Crash!!!"
        Automaton.finish()
      end
    end

    test "dispatches Crashed event on crash" do
      surpress_crash_log()

      saga_id = SagaID.new()
      Dispatcher.listen_event_type(Saga.Crashed)

      Dispatcher.dispatch(
        Event.new(nil, %StartSaga{
          id: saga_id,
          saga: %TestAutomatonCrash{}
        })
      )

      assert_receive %Event{
        body: %Saga.Crashed{
          id: ^saga_id,
          reason: %RuntimeError{},
          stacktrace: [{TestAutomatonCrash, _, _, _} | _]
        }
      }
    end

    defmodule TestAutomatonQueue do
      use Automaton
      defstruct [:pid, :a, :b, :c]

      @impl true
      def spawn(id, state) do
        perform id, %Subscribe{event_filter: EventFilter.new(event_type: TestEvent)}
        state
      end

      @impl true
      def yield(id, %__MODULE__{pid: pid, a: a, b: b, c: c}) do
        send(pid, perform(id, %Receive{event_filter: EventFilter.new(source_saga_id: a)}))
        send(pid, perform(id, %Receive{event_filter: EventFilter.new(source_saga_id: c)}))
        send(pid, perform(id, %Receive{event_filter: EventFilter.new(source_saga_id: b)}))
        Automaton.finish()
      end
    end

    test "stores ignored events in queue" do
      pid = self()
      a = TestHelper.launch_test_saga()
      b = TestHelper.launch_test_saga()
      c = TestHelper.launch_test_saga()

      assert_handle(fn id ->
        perform id, %Start{
          saga: %TestAutomatonQueue{pid: pid, a: a, b: b, c: c}
        }
      end)

      Dispatcher.dispatch(Event.new(a, %TestEvent{}))
      Dispatcher.dispatch(Event.new(b, %TestEvent{extra: :first}))
      Dispatcher.dispatch(Event.new(b, %TestEvent{extra: :second}))
      Dispatcher.dispatch(Event.new(c, %TestEvent{}))
      assert_receive %Event{source_saga_id: ^a, body: %TestEvent{}}
      assert_receive %Event{source_saga_id: ^b, body: %TestEvent{extra: :first}}
      assert_receive %Event{source_saga_id: ^c, body: %TestEvent{}}
    end

    defmodule TestRequest do
      use Cizen.Request
      defstruct []

      defresponse Response, :request_id do
        defstruct [:request_id]
      end
    end

    defmodule TestAutomatonDump do
      use Automaton
      defstruct [:pid]

      @impl true
      def spawn(id, state) do
        perform id, %Subscribe{event_filter: EventFilter.new(event_type: TestEvent)}
        state
      end

      @impl true
      def yield(id, %__MODULE__{pid: pid}) do
        perform id, %Receive{}

        response =
          perform id, %Race{
            effects: [
              %Request{body: %TestRequest{}},
              %Request{body: %TestRequest{}}
            ]
          }

        send(pid, response.body)
        perform id, %Receive{event_filter: %EventFilter{event_type: UnknownEvent}}
        Automaton.finish()
      end
    end

    test "dumps ignored Response events in queue" do
      pid = self()

      spawn_link(fn ->
        Dispatcher.listen_event_type(TestRequest)

        receive do
          %Event{id: id} ->
            Dispatcher.dispatch(Event.new(nil, %TestRequest.Response{request_id: id}))
        end

        receive do
          %Event{id: id} ->
            Dispatcher.dispatch(Event.new(nil, %TestRequest.Response{request_id: id}))
        end

        send(pid, :responsed)
      end)

      saga_id =
        assert_handle(fn id ->
          perform id, %Start{
            saga: %TestAutomatonDump{pid: pid}
          }
        end)

      {:ok, pid} = CizenSagaRegistry.get_pid(saga_id)

      old =
        pid
        |> :sys.get_state()
        |> elem(2)
        |> elem(1)

      Dispatcher.dispatch(Event.new(nil, %TestEvent{}))

      receive do
        :responsed -> :ok
      end

      assert_receive %TestRequest.Response{}

      :timer.sleep(10)

      new =
        pid
        |> :sys.get_state()
        |> elem(2)
        |> elem(1)

      assert old.event_buffer == new.event_buffer
    end
  end
end
