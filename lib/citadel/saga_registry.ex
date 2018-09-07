defmodule Citadel.SagaRegistry do
  @moduledoc """
  The registry for automata.
  """

  alias Citadel.SagaID

  def start_link do
    Registry.start_link(keys: :unique, name: __MODULE__)
  end

  @doc """
  Resolve an saga id to a pid.
  """
  @spec resolve_id(SagaID.t()) :: {:ok, pid} | :error
  def resolve_id(id) do
    case Registry.lookup(__MODULE__, id) do
      [{pid, _}] -> {:ok, pid}
      _ -> :error
    end
  end
end
