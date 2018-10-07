defmodule Citadel.Automaton.Effects.Map do
  @moduledoc """
  An effect to transform the result of effect.

  Returns the transformed result.
  """

  defstruct [:effect, :transform]

  alias Citadel.Automaton.Effect

  @behaviour Effect

  @impl true
  def init(id, %__MODULE__{effect: effect, transform: transform}) do
    case Effect.init(id, effect) do
      {:resolve, result} ->
        {:resolve, transform.(result)}

      other ->
        other
    end
  end

  @impl true
  def handle_event(id, event, %__MODULE__{effect: effect, transform: transform}, state) do
    case Effect.handle_event(id, event, effect, state) do
      {:resolve, result} ->
        {:resolve, transform.(result)}

      {:consume, state} ->
        {:consume, state}

      other ->
        other
    end
  end
end
