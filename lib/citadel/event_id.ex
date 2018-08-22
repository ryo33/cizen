defmodule Citadel.EventID do
  @moduledoc """
  Each event has a unique automaton-id.
  """

  @type t :: String.t()

  @doc """
  Create new event id.
  """
  @spec new :: t
  def new do
    UUID.uuid4()
  end
end
