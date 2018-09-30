defmodule Citadel.EventFilterDispatcher.SubscriptionRegisterer do
  @moduledoc false

  use GenServer

  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.EventFilterDispatcher.SubscriptionRegistry
  alias Citadel.SagaRegistry
  alias Citadel.SubscribeEventFilter

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_args) do
    Dispatcher.listen_event_type(SubscribeEventFilter)
    {:ok, :ok}
  end

  @impl true
  def handle_info(%Event{body: body}, :ok) do
    handle_event(body, :ok)
  end

  def handle_event(%SubscribeEventFilter{subscription: subscription}, :ok) do
    case SagaRegistry.resolve_id(subscription.subscriber_saga_id) do
      {:ok, pid} ->
        spawn_link(fn ->
          Process.link(pid)
          Process.flag(:trap_exit, true)
          Registry.register(SubscriptionRegistry, :subscriptions, subscription)

          Dispatcher.dispatch(
            Event.new(%SubscribeEventFilter.Subscribed{subscription: subscription})
          )

          receive do
            _ -> :ok
          end
        end)

      _ ->
        :ok
    end

    {:noreply, :ok}
  end
end
