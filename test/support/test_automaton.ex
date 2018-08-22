defmodule Citadel.TestAutomaton do
  @moduledoc false
  @behaviour Citadel.Automaton
  @impl Citadel.Automaton
  def launch(id, func), do: func.(id)
end
