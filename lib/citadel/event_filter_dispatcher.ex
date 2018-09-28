defmodule Citadel.EventFilterDispatcher do
  @moduledoc """
  A dispatcher based on subscription with filter set.
  """

  use GenServer

  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.EventFilterDispatcher.SubscriptionRegistry
  alias Citadel.EventFilterSubscription
  alias Citadel.SagaRegistry

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_args) do
    Dispatcher.listen_all()
    {:ok, :ok}
  end

  @impl true
  def handle_info(%Event{} = event, state) do
    subscriptions = SubscriptionRegistry.subscriptions()

    Enum.each(subscriptions, fn subscription -> dispatch(subscription, event) end)

    {:noreply, state}
  end

  defp dispatch(subscription, event) do
    if EventFilterSubscription.match?(subscription, event) do
      case SagaRegistry.resolve_id(subscription.subscriber_saga_id) do
        {:ok, pid} -> send(pid, event)
        _ -> :ok
      end
    end
  end
end
