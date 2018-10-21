defmodule Cizen.Effects.MapTest do
  use Cizen.SagaCase
  alias Cizen.EffectTestHelper.{TestEffect, TestEvent}

  alias Cizen.Automaton
  alias Cizen.Dispatcher
  alias Cizen.Effect
  alias Cizen.Event
  alias Cizen.EventFilter
  alias Cizen.Messenger
  alias Cizen.Saga
  alias Cizen.SagaID

  alias Cizen.StartSaga

  use Cizen.Effects, only: [Map]

  describe "Map" do
    test "transform the result when the effect immediately resolves" do
      id = SagaID.new()

      effect = %Map{
        effect: %TestEffect{value: :a, resolve_immediately: true},
        transform: fn :a -> :transformed_a end
      }

      assert {:resolve, :transformed_a} == Effect.init(id, effect)
    end

    test "returns the state of the effect on init" do
      id = SagaID.new()

      effect = %Map{
        effect: %TestEffect{value: :a},
        transform: fn :a -> :transformed_a end
      }

      assert {effect, {effect.effect, :a}} == Effect.init(id, effect)
    end

    test "transforms the result when the effect resolves" do
      id = SagaID.new()

      effect = %Map{
        effect: %TestEffect{value: :a},
        transform: fn :a -> :transformed_a end
      }

      {effect, state} = Effect.init(id, effect)
      event = Event.new(%TestEvent{value: :a})
      assert {:resolve, :transformed_a} == Effect.handle_event(id, event, effect, state)
    end

    test "consumes an event" do
      id = SagaID.new()

      effect = %Map{
        effect: %TestEffect{value: :a},
        transform: fn :a -> :transformed_a end
      }

      {effect, state} = Effect.init(id, effect)
      event = Event.new(%TestEvent{value: :b})
      assert {:consume, {effect.effect, :a}} == Effect.handle_event(id, event, effect, state)
    end

    test "ignores an event" do
      id = SagaID.new()

      effect = %Map{
        effect: %TestEffect{value: :a},
        transform: fn :a -> :transformed_a end
      }

      {effect, state} = Effect.init(id, effect)
      event = Event.new(%TestEvent{value: :ignored})
      assert {effect.effect, :a} == Effect.handle_event(id, event, effect, state)
    end

    test "works with alias" do
      id = SagaID.new()

      effect = %Map{
        effect: %TestEffect{value: :a, alias_of: %TestEffect{value: :b}},
        transform: fn
          :a -> :transformed_a
          :b -> :transformed_b
        end
      }

      {effect, state} = Effect.init(id, effect)
      assert {effect.effect.alias_of, :b} == state
      event = Event.new(%TestEvent{value: :b})
      assert {:resolve, :transformed_b} == Effect.handle_event(id, event, effect, state)
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

        send(
          pid,
          perform(id, %Map{
            effect: %TestEffect{value: :a, resolve_immediately: true},
            transform: fn :a -> :transformed_a end
          })
        )

        send(
          pid,
          perform(id, %Map{
            effect: %TestEffect{value: :b},
            transform: fn :b -> :transformed_b end
          })
        )

        Automaton.finish()
      end
    end

    test "transforms the result" do
      saga_id = SagaID.new()
      Dispatcher.listen_event_body(%Saga.Finish{id: saga_id})

      Dispatcher.dispatch(
        Event.new(%StartSaga{
          id: saga_id,
          saga: %TestAutomaton{pid: self()}
        })
      )

      assert_receive :launched

      assert_receive :transformed_a

      Dispatcher.dispatch(
        Event.new(%TestEvent{
          value: :c
        })
      )

      Dispatcher.dispatch(
        Event.new(%TestEvent{
          value: :ignored
        })
      )

      Dispatcher.dispatch(
        Event.new(%TestEvent{
          value: :b
        })
      )

      assert_receive :transformed_b

      assert_receive %Event{body: %Saga.Finish{id: ^saga_id}}
    end
  end
end
