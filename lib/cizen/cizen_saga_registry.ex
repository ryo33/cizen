defmodule Cizen.CizenSagaRegistry do
  @moduledoc """
  The registry to store all sagas in Cizen.
  """

  def start_link do
    Registry.start_link(keys: :unique, name: Cizen.CizenSagaRegistry)
  end

  def get_pid(id) do
    case Registry.lookup(__MODULE__, id) do
      [{pid, _}] -> {:ok, pid}
      _ -> :error
    end
  end

  def get_saga(id) do
    case Registry.lookup(__MODULE__, id) do
      [{_, saga}] -> {:ok, saga}
      _ -> :error
    end
  end
end
