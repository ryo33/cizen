defmodule Citadel.EffectHandlerTestHelper do
  @moduledoc false

  defmodule TestEvent do
    @moduledoc false
    defstruct [:value, :count]
  end

  defmodule TestEffect do
    @moduledoc false
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
end
