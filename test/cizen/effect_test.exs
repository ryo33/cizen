defmodule Cizen.EffectTest do
  use ExUnit.Case
  alias Cizen.EffectTestHelper.TestEvent

  alias Cizen.Effect
  alias Cizen.Event
  alias Cizen.SagaID

  defmodule TestEffect do
    defstruct [:init_value, :handle_event_value, :alias_of]

    alias Cizen.Effect
    @behaviour Effect

    @impl true
    def init(_handler, effect) do
      if is_nil(effect.alias_of) do
        effect.init_value
      else
        {:alias_of, effect.alias_of}
      end
    end

    @impl true
    def handle_event(_handler, _event, effect, _state) do
      effect.handle_event_value
    end
  end

  describe "Effect.init/2" do
    test "resolves" do
      id = SagaID.new()
      effect = %TestEffect{init_value: {:resolve, :a}}
      assert {:resolve, :a} = Effect.init(id, effect)
    end

    test "recursively use aliases" do
      id = SagaID.new()
      final_effect = %TestEffect{init_value: :a}

      effect = %TestEffect{
        alias_of: %TestEffect{
          alias_of: final_effect
        }
      }

      assert {^final_effect, :a} = Effect.init(id, effect)
    end
  end

  describe "Effect.handle_event/2" do
    test "returns the same result as the given effect" do
      id = SagaID.new()
      effect = %TestEffect{handle_event_value: :a}
      event = Event.new(nil, %TestEvent{})
      assert :a = Effect.handle_event(id, event, effect, :ok)
    end
  end
end
