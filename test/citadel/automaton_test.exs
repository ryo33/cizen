defmodule Citadel.AutomatonTest do
  use ExUnit.Case
  alias Citadel.TestHelper

  alias Citadel.Automaton
  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.EventFilter
  alias Citadel.Message
  alias Citadel.Messenger
  alias Citadel.Saga
  alias Citadel.SagaID

  alias Citadel.Automaton.PerformEffect
  alias Citadel.EventFilterDispatcher.PushEvent
  alias Citadel.ReceiveMessage
  alias Citadel.StartSaga

  defmodule(TestEvent, do: defstruct([:value, :count]))

  defmodule TestEffect do
    defstruct [:value, :resolve_immediately, :reset, :alias_of]

    alias Citadel.Automaton.Effect
    @behaviour Effect

    @impl true
    def init(_handler, effect) do
      if is_nil(effect.alias_of) do
        count = 0

        if effect.resolve_immediately do
          {:resolve, {effect.value, count}}
        else
          count
        end
      else
        {:alias_of, effect.alias_of}
      end
    end

    @impl true
    def handle_event(_handler, event, effect, count) do
      if event.body.value == effect.value do
        count = count + 1

        if event.body.count <= count do
          {:resolve, {effect.value, count}}
        else
          {:consume, count}
        end
      else
        if effect.reset do
          0
        else
          count
        end
      end
    end
  end

  defp setup_state(_context) do
    pid = self()
    %{pid: pid, effect: nil, effect_state: nil, event_buffer: []}
  end

  defp do_perform(state, effect) do
    saga_id = SagaID.new()

    event =
      Event.new(%PushEvent{
        saga_id: saga_id,
        event: Event.new(%PerformEffect{effect: effect}),
        # This should not be empty.
        subscriptions: []
      })

    Automaton.handle_event(saga_id, event, state)
  end

  defp feed(state, body) do
    event =
      Event.new(%ReceiveMessage{
        message: %Message{
          event: Event.new(body),
          destination_saga_id: nil,
          destination_saga_module: nil
        }
      })

    Automaton.handle_event(SagaID.new(), event, state)
  end

  describe "Automaton.handle_event/3" do
    setup [:setup_state]

    test "resolves immediately", state do
      state =
        state
        |> do_perform(%TestEffect{resolve_immediately: true, value: :a})

      assert_receive {:a, 0}
      assert state.effect == nil
      assert state.event_buffer == []
    end

    test "resolves on event which will come after PerformEffect event", state do
      state =
        state
        |> do_perform(%TestEffect{value: :a})
        |> feed(%TestEvent{value: :a, count: 1})

      assert_receive {:a, 1}
      assert state.effect == nil
      assert state.event_buffer == []
    end

    test "resolves on event which came before PerformEffect event", state do
      state =
        state
        |> feed(%TestEvent{value: :a, count: 1})
        |> do_perform(%TestEffect{value: :a})

      assert_receive {:a, 1}
      assert state.effect == nil
      assert state.event_buffer == []
    end

    test "feeds events from the buffer", state do
      state =
        state
        |> feed(%TestEvent{value: :a, count: 3})
        |> feed(%TestEvent{value: :a, count: 3})
        |> feed(%TestEvent{value: :a, count: 3})
        |> do_perform(%TestEffect{value: :a})

      assert_receive {:a, 3}
      assert state.effect == nil
      assert state.event_buffer == []
    end

    test "does not resolve for unmatched events", state do
      effect = %TestEffect{value: :a}
      event_2 = %TestEvent{value: :b, count: 2}

      state =
        state
        |> do_perform(effect)
        |> feed(%TestEvent{value: :a, count: 2})
        |> feed(event_2)

      refute_receive {:a, _}
      assert state.effect == %TestEffect{value: :a}
      assert Enum.map(state.event_buffer, & &1.body) == [event_2]
    end

    test "keep only not consumed events in the buffer", state do
      effect = %TestEffect{value: :a}
      event_1 = %TestEvent{value: :b, count: 1}
      event_2 = %TestEvent{value: :b, count: 2}

      state =
        state
        |> feed(event_1)
        |> feed(%TestEvent{value: :a, count: 3})
        |> do_perform(effect)
        |> feed(event_2)
        |> feed(%TestEvent{value: :a, count: 3})
        |> feed(%TestEvent{value: :a, count: 3})

      assert Enum.map(state.event_buffer, & &1.body) == [event_1, event_2]
    end

    test "keep not consumed events in the buffer after resolve", state do
      effect = %TestEffect{value: :a}
      event_1 = %TestEvent{value: :b, count: 1}
      event_2 = %TestEvent{value: :b, count: 2}

      state =
        state
        |> feed(event_1)
        |> feed(%TestEvent{value: :a, count: 1})
        |> feed(event_2)
        |> do_perform(effect)

      assert Enum.map(state.event_buffer, & &1.body) == [event_1, event_2]
    end

    test "update the effect state", initial_state do
      state =
        initial_state
        |> feed(%TestEvent{value: :a, count: 2})
        |> do_perform(%TestEffect{reset: true, value: :a})

      assert state.effect_state == 1

      state =
        initial_state
        |> feed(%TestEvent{value: :a, count: 2})
        |> feed(%TestEvent{value: :b, count: 1})
        |> do_perform(%TestEffect{reset: true, value: :a})

      assert state.effect_state == 0

      state =
        initial_state
        |> feed(%TestEvent{value: :a, count: 3})
        |> do_perform(%TestEffect{reset: true, value: :a})
        |> feed(%TestEvent{value: :a, count: 3})

      assert state.effect_state == 2

      state =
        initial_state
        |> feed(%TestEvent{value: :a, count: 3})
        |> do_perform(%TestEffect{reset: true, value: :a})
        |> feed(%TestEvent{value: :a, count: 3})
        |> feed(%TestEvent{value: :b, count: 1})

      assert state.effect_state == 0
    end

    test "resolves immediately with using alias", state do
      state =
        state
        |> do_perform(%TestEffect{
          value: :b,
          alias_of: %TestEffect{resolve_immediately: true, value: :a}
        })

      assert_receive {:a, 0}
      assert state.effect == nil
      assert state.event_buffer == []
    end

    test "resolves with using alias", state do
      state =
        state
        |> feed(%TestEvent{value: :b, count: 2})
        |> do_perform(%TestEffect{
          value: :a,
          alias_of: %TestEffect{value: :b}
        })
        |> feed(%TestEvent{value: :b, count: 2})

      assert_receive {:b, 2}
      assert state.effect == nil
      assert state.event_buffer == []
    end
  end

  describe "Automaton.perform/2" do
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
    defmodule TestAutomatonFinish do
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
          saga: %TestAutomatonFinish{}
        })
      )

      assert_receive %Event{body: %Saga.Finish{id: ^saga_id}}

      TestHelper.ensure_finished(saga_id)
    end

    defmodule TestAutomatonNotFinish do
      use Automaton

      defstruct []

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

      TestHelper.ensure_finished(saga_id)
    end

    defmodule TestAutomaton do
      use Automaton

      defstruct [:pid]

      @impl true
      def yield(id, %__MODULE__{pid: pid}) do
        Messenger.subscribe_message(id, __MODULE__, %EventFilter{
          event_type: TestEvent
        })

        send(pid, :launched)
        {:a, pid}
      end

      def yield(id, {:a, pid}) do
        send(pid, perform(id, %TestEffect{value: :a}))
        {:b, pid}
      end

      def yield(id, {:b, pid}) do
        send(pid, perform(id, %TestEffect{value: :b}))
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
          value: :b,
          count: 2
        })
      )

      Dispatcher.dispatch(
        Event.new(%TestEvent{
          value: :a,
          count: 1
        })
      )

      assert_receive {:a, 1}

      Dispatcher.dispatch(
        Event.new(%TestEvent{
          value: :b,
          count: 3
        })
      )

      Dispatcher.dispatch(
        Event.new(%TestEvent{
          value: :b,
          count: 3
        })
      )

      assert_receive {:b, 3}

      assert_receive %Event{body: %Saga.Finish{id: ^saga_id}}

      TestHelper.ensure_finished(saga_id)
    end
  end
end
