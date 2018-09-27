defmodule Citadel.SubscriptiveDispatcher do
  @moduledoc """
  A dispatcher based on subscription with filter set.
  """

  use GenServer

  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.SagaRegistry
  alias Citadel.Subscription
  alias Citadel.SubscriptiveDispatcher.SubscriptionRegistry

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
    if Subscription.match?(subscription, event) do
      case SagaRegistry.resolve_id(subscription.subscriber_saga_id) do
        {:ok, pid} -> send(pid, event)
        _ -> :ok
      end
    end
  end
end
