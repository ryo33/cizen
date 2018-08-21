defmodule Citadel.Automaton do
  @moduledoc """
  The automaton behaviour
  """

  alias Citadel.AutomatonID

  @doc false
  @callback launch(AutomatonID.t(), state :: any) :: {:ok, pid}
end
