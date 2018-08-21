defmodule Citadel.AutomatonID do
  @moduledoc """
  Each automaton has a unique automaton-id.
  """

  @type t :: String.t()

  @doc """
  Create new automaton id.
  """
  @spec new :: t
  def new do
    UUID.uuid4()
  end
end
