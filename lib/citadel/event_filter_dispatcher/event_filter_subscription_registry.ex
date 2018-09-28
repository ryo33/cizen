defmodule Citadel.EventFilterDispatcher.SubscriptionRegistry do
  @moduledoc """
  A registry to store subscriptions.
  """

  alias Citadel.EventFilterSubscription

  @doc """
  Returns a list of subscriptions.
  """
  @spec subscriptions() :: list(EventFilterSubscription.t())
  def subscriptions do
    records = Registry.lookup(__MODULE__, :subscriptions)
    Enum.map(records, fn {_pid, value} -> value end)
  end

  def start_link do
    Registry.start_link(keys: :duplicate, name: __MODULE__)
  end
end
