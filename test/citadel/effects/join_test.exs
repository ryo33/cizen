defmodule Citadel.Effects.JoinTest do
  use ExUnit.Case
  alias Citadel.EffectTestHelper.{TestEffect, TestEvent}
  alias Citadel.TestHelper

  alias Citadel.Automaton
  alias Citadel.Dispatcher
  alias Citadel.Effect
  alias Citadel.Effects.Join
  alias Citadel.Event
  alias Citadel.EventFilter
  alias Citadel.Messenger
  alias Citadel.Saga
  alias Citadel.SagaID

  alias Citadel.StartSaga

  describe "Join" do
    test "resolves immediately with no effects" do
      id = SagaID.new()

      effect = %Join{
        effects: []
      }

      assert {:resolve, []} = Effect.init(id, effect)
    end

    test "resolves immediately if effects resolve immediately" do
      id = SagaID.new()

      effect = %Join{
        effects: [
          %TestEffect{value: :a, resolve_immediately: true},
          %TestEffect{value: :b, resolve_immediately: true}
        ]
      }

      assert {:resolve, [:a, :b]} = Effect.init(id, effect)
    end

    test "does not resolve immediately if one or more effects do not resolve immediately" do
      id = SagaID.new()

      effect = %Join{
        effects: [
          %TestEffect{value: :a, resolve_immediately: true},
          %TestEffect{value: :b}
        ]
      }

      refute match?({:resolve, _}, Effect.init(id, effect))
    end

    test "resolves when a effect resolve" do
      id = SagaID.new()

      effect = %Join{
        effects: [
          %TestEffect{value: :a, resolve_immediately: true},
          %TestEffect{value: :b}
        ]
      }

      {_, state} = Effect.init(id, effect)
      event = Event.new(%TestEvent{value: :b})
      assert {:resolve, [:a, :b]} == Effect.handle_event(id, event, effect, state)
    end

    test "consumes when the event is consumed" do
      id = SagaID.new()

      effect = %Join{
        effects: [
          %TestEffect{value: :a}
        ]
      }

      {_, state} = Effect.init(id, effect)
      event = Event.new(%TestEvent{value: :b})
      assert match?({:consume, _}, Effect.handle_event(id, event, effect, state))
    end

    test "ignores when the event is not consumed" do
      id = SagaID.new()

      effect = %Join{
        effects: [
          %TestEffect{value: :a}
        ]
      }

      {_, state} = Effect.init(id, effect)
      event = Event.new(%TestEvent{value: :ignored})
      state = Effect.handle_event(id, event, effect, state)
      refute match?({:resolve, _}, state)
      refute match?({:consume, _}, state)
    end

    test "resolves with an effect which consumes an event last time" do
      id = SagaID.new()

      effect = %Join{
        effects: [
          %TestEffect{value: :a, resolve_immediately: true},
          %TestEffect{value: :b}
        ]
      }

      {_, state} = Effect.init(id, effect)
      event = Event.new(%TestEvent{value: :c})
      {:consume, state} = Effect.handle_event(id, event, effect, state)
      event = Event.new(%TestEvent{value: :b})
      assert {:resolve, [:a, :b]} == Effect.handle_event(id, event, effect, state)
    end

    test "resolves with an effect which ignores an event last time" do
      id = SagaID.new()

      effect = %Join{
        effects: [
          %TestEffect{value: :a, resolve_immediately: true},
          %TestEffect{value: :b}
        ]
      }

      {_, state} = Effect.init(id, effect)
      event = Event.new(%TestEvent{value: :ignored})
      state = Effect.handle_event(id, event, effect, state)
      event = Event.new(%TestEvent{value: :b})
      assert {:resolve, [:a, :b]} == Effect.handle_event(id, event, effect, state)
    end

    test "consumes if there are not resolved effects" do
      id = SagaID.new()

      effect = %Join{
        effects: [
          %TestEffect{value: :a},
          %TestEffect{value: :b}
        ]
      }

      {_, state} = Effect.init(id, effect)
      event = Event.new(%TestEvent{value: :a})
      assert {:consume, _} = Effect.handle_event(id, event, effect, state)
    end

    test "resolves after consumes" do
      id = SagaID.new()

      effect = %Join{
        effects: [
          %TestEffect{value: :a},
          %TestEffect{value: :b, resolve_immediately: true},
          %TestEffect{value: :c}
        ]
      }

      {_, state} = Effect.init(id, effect)
      event = Event.new(%TestEvent{value: :a})
      {:consume, state} = Effect.handle_event(id, event, effect, state)

      event = Event.new(%TestEvent{value: :c})
      {:resolve, [:a, :b, :c]} = Effect.handle_event(id, event, effect, state)
    end

    test "resolves if all following effects resolve immediately" do
      id = SagaID.new()

      effect = %Join{
        effects: [
          %TestEffect{value: :a, alias_of: %TestEffect{value: :b}}
        ]
      }

      {_, state} = Effect.init(id, effect)
      event = Event.new(%TestEvent{value: :b})
      assert {:resolve, [:b]} == Effect.handle_event(id, event, effect, state)
    end

    test "works with aliases" do
      id = SagaID.new()

      effect = %Join{
        effects: [
          %TestEffect{value: :a},
          %TestEffect{value: :b, resolve_immediately: true},
          %TestEffect{value: :c, resolve_immediately: true}
        ]
      }

      {_, state} = Effect.init(id, effect)
      event = Event.new(%TestEvent{value: :a})
      assert {:resolve, [:a, :b, :c]} == Effect.handle_event(id, event, effect, state)
    end

    test "pass the results to the functions" do
      id = SagaID.new()

      effect = %Join{
        effects: [
          fn ->
            %TestEffect{value: :a}
          end,
          %TestEffect{value: :b, resolve_immediately: true},
          fn a, b ->
            assert a == :a
            assert b == :b
            %TestEffect{value: :c}
          end
        ]
      }

      {_, state} = Effect.init(id, effect)
      event = Event.new(%TestEvent{value: :a})
      {:consume, state} = Effect.handle_event(id, event, effect, state)
      event = Event.new(%TestEvent{value: :c})
      assert {:resolve, [:a, :b, :c]} == Effect.handle_event(id, event, effect, state)
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
          perform(id, %Join{
            effects: [
              %TestEffect{value: :a, resolve_immediately: true},
              fn :a -> %TestEffect{value: :b} end,
              %TestEffect{value: :c}
            ]
          })
        )

        Automaton.finish()
      end
    end

    test "works with Automaton" do
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
          value: :b
        })
      )

      Dispatcher.dispatch(
        Event.new(%TestEvent{
          value: :c
        })
      )

      assert_receive [:a, :b, :c]

      assert_receive %Event{body: %Saga.Finish{id: ^saga_id}}

      TestHelper.ensure_finished(saga_id)
    end
  end
end
