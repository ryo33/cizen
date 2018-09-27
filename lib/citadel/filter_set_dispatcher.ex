defmodule Citadel.FilterSetDispatcher do
  @moduledoc """
  A dispatcher based on subscription with filter set.
  """

  use GenServer

  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.Filter
  alias Citadel.FilterSetDispatcher.SubscriptionRegistry
  alias Citadel.SagaRegistry
  alias Citadel.Subscription

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

    Enum.each(subscriptions, fn %Subscription{saga_id: saga_id, filter_set: filter_set} ->
      dispatch(saga_id, filter_set, event)
    end)

    {:noreply, state}
  end

  defp dispatch(saga_id, filter_set, event) do
    if Enum.all?(filter_set.filters, fn %Filter{module: module, opts: opts} ->
         module.test(event, opts)
       end) do
      case SagaRegistry.resolve_id(saga_id) do
        {:ok, pid} -> send(pid, event)
        _ -> :ok
      end
    end
  end
end
