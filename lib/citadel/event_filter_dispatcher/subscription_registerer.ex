defmodule Citadel.EventFilterDispatcher.SubscriptionRegisterer do
  @moduledoc false

  use GenServer

  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.EventFilterDispatcher.SubscriptionRegisterer.SubscriptionKeeper
  alias Citadel.EventFilterDispatcher.SubscriptionRegistry
  alias Citadel.EventFilterSubscribed
  alias Citadel.Saga
  alias Citadel.SagaID
  alias Citadel.SagaLauncher
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
        Dispatcher.dispatch(
          Event.new(%SagaLauncher.LaunchSaga{
            id: SagaID.new(),
            module: SubscriptionKeeper,
            state: {subscription.subscriber_saga_id, pid, subscription}
          })
        )

      _ ->
        :ok
    end

    {:noreply, :ok}
  end

  defmodule SubscriptionKeeper do
    @moduledoc """
    A saga to keep the subscription until the saga Finish.
    """

    @behaviour Saga

    @impl true
    def launch(_id, {target_saga_id, target_pid, subscription} = state) do
      Dispatcher.listen_event_body(%Saga.Finish{id: target_saga_id})
      Dispatcher.listen_event_body(%Saga.Finished{id: target_saga_id})
      Registry.register(SubscriptionRegistry, :subscriptions, subscription)
      Process.link(target_pid)

      Dispatcher.dispatch(Event.new(%EventFilterSubscribed{subscription: subscription}))
      state
    end

    @impl true
    def handle_event(id, %Event{body: %Saga.Finish{id: target_saga_id}}, {target_saga_id, _, _}) do
      Dispatcher.dispatch(Event.new(%Saga.Finish{id: id}))
    end

    @impl true
    def handle_event(id, %Event{body: %Saga.Finished{id: target_saga_id}}, {target_saga_id, _, _}) do
      Dispatcher.dispatch(Event.new(%Saga.Finish{id: id}))
    end
  end
end
