defmodule Citadel.Automaton.Effects.Receive do
  @moduledoc """
  An effect to receive an event.

  Returns the received event.
  """

  defstruct [:event_filter]

  alias Citadel.Automaton.Effect
  alias Citadel.EventFilter

  @behaviour Effect

  @impl true
  def init(_handler, %__MODULE__{}) do
    :ok
  end

  @impl true
  def handle_event(_handler, event, effect, state) do
    if EventFilter.test(effect.event_filter, event) do
      {:resolve, event}
    else
      state
    end
  end
end
