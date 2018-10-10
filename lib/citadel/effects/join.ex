defmodule Citadel.Effects.Join do
  @moduledoc """
  An effect to join multiple effects.

  Returns the list of resolved values.

  ## Example
        [result1, result2] = perform id, %Join{
          effects: [effect1, effect2]
        }
  """

  defstruct [:effects]

  alias Citadel.Effect

  @behaviour Effect

  @impl true
  def init(id, %__MODULE__{effects: effects}) do
    {values, effects, effect_state} = do_init(id, effects)

    if effects == [] do
      {:resolve, Enum.reverse(values)}
    else
      {values, effects, effect_state}
    end
  end

  @impl true
  def handle_event(id, event, _, {values, [effect | tail] = effects, effect_state}) do
    case Effect.handle_event(id, event, effect, effect_state) do
      {:resolve, value} ->
        if tail == [] do
          {:resolve, Enum.reverse([value | values])}
        else
          {values, effects, effect_state} = do_init(id, tail, [value | values])

          if effects == [] do
            {:resolve, Enum.reverse(values)}
          else
            {:consume, {values, effects, effect_state}}
          end
        end

      {:consume, state} ->
        {:consume, {values, effects, state}}

      state ->
        {values, effects, state}
    end
  end

  defp do_init(id, effects, values \\ [])
  defp do_init(_id, [], values), do: {values, [], nil}

  defp do_init(id, [effect | tail], values) do
    effect =
      if is_function(effect) do
        apply(effect, Enum.reverse(values))
      else
        effect
      end

    case Effect.init(id, effect) do
      {:resolve, value} ->
        do_init(id, tail, [value | values])

      {effect, state} ->
        {values, [effect | tail], state}
    end
  end
end
