defmodule Citadel.Automaton.Effects.JoinTest do
  use ExUnit.Case
  alias Citadel.TestHelper

  alias Citadel.Automaton
  alias Citadel.Automaton.Effect
  alias Citadel.Automaton.Effects.Join
  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.EventFilter
  alias Citadel.Messenger
  alias Citadel.Saga
  alias Citadel.SagaID

  alias Citadel.StartSaga

  defmodule(TestEvent, do: defstruct([:value]))

  defmodule TestEffect do
    defstruct [:value, :resolve_immediately]

    alias Citadel.Automaton.Effect
    @behaviour Effect

    @impl true
    def init(_handler, effect) do
      if effect.resolve_immediately do
        {:resolve, effect.value}
      else
        effect.value
      end
    end

    @impl true
    def handle_event(_handler, event, %__MODULE__{value: value}, value) do
      if event.body.value == :ignored do
        value
      else
        if value == event.body.value do
          {:resolve, value}
        else
          {:consume, value}
        end
      end
    end
  end

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

      state = Effect.init(id, effect)
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

      state = Effect.init(id, effect)
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

      state = Effect.init(id, effect)
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

      state = Effect.init(id, effect)
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

      state = Effect.init(id, effect)
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

      state = Effect.init(id, effect)
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

      state = Effect.init(id, effect)
      event = Event.new(%TestEvent{value: :a})
      {:consume, state} = Effect.handle_event(id, event, effect, state)

      event = Event.new(%TestEvent{value: :c})
      {:resolve, [:a, :b, :c]} = Effect.handle_event(id, event, effect, state)
    end

    test "resolves if all following effects resolve immediately" do
      id = SagaID.new()

      effect = %Join{
        effects: [
          %TestEffect{value: :a},
          %TestEffect{value: :b, resolve_immediately: true},
          %TestEffect{value: :c, resolve_immediately: true}
        ]
      }

      state = Effect.init(id, effect)
      event = Event.new(%TestEvent{value: :a})
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
              %TestEffect{value: :b},
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

      # performance issue
      assert_receive [:a, :b, :c], 1000

      assert_receive %Event{body: %Saga.Finish{id: ^saga_id}}

      TestHelper.ensure_finished(saga_id)
    end
  end
end