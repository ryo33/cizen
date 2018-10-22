defmodule Cizen.CizenSagaRegistry do
  @moduledoc """
  The registry to store all sagas in Cizen.
  """

  alias Cizen.Saga
  alias Cizen.SagaID

  def start_link do
    Registry.start_link(keys: :unique, name: Cizen.CizenSagaRegistry)
  end

  @doc """
  Returns the pid for the given saga ID.
  """
  @spec get_pid(SagaID.t()) :: {:ok, pid} | :error
  def get_pid(id) do
    case Registry.lookup(__MODULE__, id) do
      [{pid, _}] -> {:ok, pid}
      _ -> :error
    end
  end

  @doc """
  Returns the saga struct for the given saga ID.
  """
  @spec get_saga(SagaID.t()) :: {:ok, Saga.t()} | :error
  def get_saga(id) do
    case Registry.lookup(__MODULE__, id) do
      [{_, saga}] -> {:ok, saga}
      _ -> :error
    end
  end
end
