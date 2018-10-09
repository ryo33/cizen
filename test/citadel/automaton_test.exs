defmodule Citadel.AutomatonTest do
  use Citadel.SagaCase
  alias Citadel.EffectHandlerTestHelper.{TestEffect, TestEvent}

  alias Citadel.Automaton
  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.EventFilter
  alias Citadel.Messenger
  alias Citadel.Saga
  alias Citadel.SagaID

  alias Citadel.Automaton.PerformEffect
  alias Citadel.StartSaga

  describe "perform/2" do
    test "dispatches PerformEffect event" do
      import Automaton, only: [perform: 2]

      Dispatcher.listen_event_type(PerformEffect)
      saga_id = SagaID.new()
      effect = %TestEffect{value: :a}

      spawn_link(fn ->
        perform(saga_id, effect)
      end)

      assert_receive %Event{body: %PerformEffect{effect: ^effect}, source_saga_id: ^saga_id}
    end

    test "block until message is coming and returns the message" do
      import Automaton, only: [perform: 2]
      current = self()

      pid =
        spawn_link(fn ->
          assert :value == perform(SagaID.new(), %TestEffect{value: :a})
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
        Event.new(%StartSaga{
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
        Event.new(%StartSaga{
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
        Event.new(%StartSaga{
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
        Messenger.subscribe_message(id, __MODULE__, %EventFilter{
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
        Event.new(%StartSaga{
          id: saga_id,
          saga: %TestAutomaton{pid: self()}
        })
      )

      assert_receive :launched

      Dispatcher.dispatch(
        Event.new(%TestEvent{
          value: :a,
          count: 1
        })
      )

      assert_receive {:a, 1}

      Dispatcher.dispatch(
        Event.new(%TestEvent{
          value: :c,
          count: 2
        })
      )

      Dispatcher.dispatch(
        Event.new(%TestEvent{
          value: :b,
          count: 1
        })
      )

      assert_receive {:b, 1}

      Dispatcher.dispatch(
        Event.new(%TestEvent{
          value: :c,
          count: 3
        })
      )

      Dispatcher.dispatch(
        Event.new(%TestEvent{
          value: :c,
          count: 3
        })
      )

      assert_receive {:c, 3}

      assert_receive %Event{body: %Saga.Finish{id: ^saga_id}}
    end

    test "dispatches Saga.Launched event after spawn/2" do
      saga_id = SagaID.new()
      Dispatcher.listen_event_body(%Saga.Finish{id: saga_id})
      Dispatcher.listen_event_body(%Saga.Launched{id: saga_id})

      Dispatcher.dispatch(
        Event.new(%StartSaga{
          id: saga_id,
          saga: %TestAutomaton{pid: self()}
        })
      )

      assert_receive :launched

      refute_receive %Event{
        body: %Saga.Launched{id: ^saga_id}
      }

      Dispatcher.dispatch(
        Event.new(%TestEvent{
          value: :a,
          count: 1
        })
      )

      assert_receive %Event{
        body: %Saga.Launched{id: ^saga_id}
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
      Dispatcher.listen_event_body(%Saga.Launched{id: saga_id})

      Dispatcher.dispatch(
        Event.new(%StartSaga{
          id: saga_id,
          saga: %TestAutomatonNoSpawn{pid: self()}
        })
      )

      assert_receive %Event{
        body: %Saga.Finish{id: ^saga_id}
      }

      assert_receive :called

      assert_receive %Event{
        body: %Saga.Launched{id: ^saga_id}
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
      Dispatcher.listen_event_body(%Saga.Launched{id: saga_id})

      Dispatcher.dispatch(
        Event.new(%StartSaga{
          id: saga_id,
          saga: %TestAutomatonNoYield{pid: self()}
        })
      )

      assert_receive :called

      assert_receive %Event{
        body: %Saga.Finish{id: ^saga_id}
      }

      assert_receive %Event{
        body: %Saga.Launched{id: ^saga_id}
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
      saga_id = SagaID.new()
      Dispatcher.listen_event_type(Saga.Crashed)

      Dispatcher.dispatch(
        Event.new(%StartSaga{
          id: saga_id,
          saga: %TestAutomatonCrash{}
        })
      )

      assert_receive %Event{body: %Saga.Crashed{id: ^saga_id, reason: %RuntimeError{}}}
    end
  end
end
