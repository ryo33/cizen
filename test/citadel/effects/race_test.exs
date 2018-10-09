defmodule Citadel.Effects.RaceTest do
  use Citadel.SagaCase
  alias Citadel.EffectTestHelper.{TestEffect, TestEvent}

  alias Citadel.Automaton
  alias Citadel.Effect
  alias Citadel.Effects.{Dispatch, Monitor, Race, Receive, Start, Subscribe}
  alias Citadel.Event
  alias Citadel.EventFilter
  alias Citadel.SagaID

  describe "Race" do
    test "resolves immediately" do
      id = SagaID.new()

      effect = %Race{
        effects: [
          %TestEffect{value: :a},
          %TestEffect{value: :b, resolve_immediately: true}
        ]
      }

      assert {:resolve, :b} = Effect.init(id, effect)
    end

    test "does not resolve immediately if all effects do not resolve immediately" do
      id = SagaID.new()

      effect = %Race{
        effects: [
          %TestEffect{value: :a},
          %TestEffect{value: :b}
        ]
      }

      refute match?({:resolve, _}, Effect.init(id, effect))
    end

    test "consumes when the event is consumed" do
      id = SagaID.new()

      effect = %Race{
        effects: [
          %TestEffect{value: :a, ignores: [:c]},
          %TestEffect{value: :b}
        ]
      }

      {_, state} = Effect.init(id, effect)
      event = Event.new(%TestEvent{value: :c})
      assert match?({:consume, _}, Effect.handle_event(id, event, effect, state))
    end

    test "ignores when the event is not consumed" do
      id = SagaID.new()

      effect = %Race{
        effects: [
          %TestEffect{value: :a},
          %TestEffect{value: :b}
        ]
      }

      {_, state} = Effect.init(id, effect)
      event = Event.new(%TestEvent{value: :ignored})
      state = Effect.handle_event(id, event, effect, state)
      refute match?({:resolve, _}, state)
      refute match?({:consume, _}, state)
    end

    test "resolves when one resolve" do
      id = SagaID.new()

      effect = %Race{
        effects: [
          %TestEffect{value: :a},
          %TestEffect{value: :b},
          %TestEffect{value: :c, ignores: [:d]}
        ]
      }

      {_, state} = Effect.init(id, effect)
      event = Event.new(%TestEvent{value: :d})
      {:consume, state} = Effect.handle_event(id, event, effect, state)
      event = Event.new(%TestEvent{value: :b})
      assert {:resolve, :b} == Effect.handle_event(id, event, effect, state)
    end

    test "works with aliases" do
      id = SagaID.new()

      effect = %Race{
        effects: [
          %TestEffect{
            value: :a,
            alias_of: %TestEffect{value: :d}
          },
          %TestEffect{
            value: :b,
            alias_of: %TestEffect{value: :e}
          },
          %TestEffect{
            value: :c,
            alias_of: %TestEffect{value: :f, ignores: [:c]}
          }
        ]
      }

      {_, state} = Effect.init(id, effect)
      event = Event.new(%TestEvent{value: :c})
      {:consume, state} = Effect.handle_event(id, event, effect, state)
      event = Event.new(%TestEvent{value: :e})
      assert {:resolve, :e} == Effect.handle_event(id, event, effect, state)
    end

    test "allows named effects" do
      id = SagaID.new()

      effect = %Race{
        effects: [
          effect_a: %TestEffect{value: :a},
          effect_b: %TestEffect{value: :b},
          effect_c: %TestEffect{value: :c, ignores: [:d]}
        ]
      }

      {_, state} = Effect.init(id, effect)
      event = Event.new(%TestEvent{value: :d})
      {:consume, state} = Effect.handle_event(id, event, effect, state)
      event = Event.new(%TestEvent{value: :b})
      assert {:resolve, {:effect_b, :b}} == Effect.handle_event(id, event, effect, state)
    end

    defmodule TestAutomaton do
      use Automaton

      defstruct [:pid]

      @impl true
      def spawn(id, struct) do
        perform(id, %Subscribe{
          event_filter: %EventFilter{
            event_type: TestEvent
          }
        })

        struct
      end

      @impl true
      def yield(id, %__MODULE__{pid: pid}) do
        send(
          pid,
          perform(id, %Race{
            effects: [
              effect1: %TestEffect{value: :a},
              effect2: %TestEffect{value: :b},
              effect3: %TestEffect{value: :d, alias_of: %TestEffect{value: :c, ignores: [:d]}}
            ]
          })
        )

        Automaton.finish()
      end
    end

    test "works with perform" do
      assert_handle(fn id ->
        saga_id =
          perform(id, %Start{
            saga: %TestAutomaton{pid: self()}
          })

        perform(id, %Dispatch{
          body: %TestEvent{
            value: :d
          }
        })

        perform(id, %Dispatch{
          body: %TestEvent{
            value: :b
          }
        })

        assert_receive {:effect2, :b}

        down_filter = perform(id, %Monitor{saga_id: saga_id})

        perform(id, %Receive{event_filter: down_filter})
      end)
    end
  end
end
