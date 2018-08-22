defmodule Citadel.AutomatonRegistry do
  @moduledoc """
  The registry for automata.
  """

  alias Citadel.AutomatonID

  def start_link do
    Registry.start_link(keys: :unique, name: __MODULE__)
  end

  @doc """
  Resolve an automaton id to a pid.
  """
  @spec resolve_id(AutomatonID.t()) :: {:ok, pid} | :error
  def resolve_id(id) do
    case Registry.lookup(__MODULE__, id) do
      [{pid, _}] -> {:ok, pid}
      _ -> :error
    end
  end
end
