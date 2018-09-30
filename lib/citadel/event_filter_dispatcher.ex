defmodule Citadel.EventFilterDispatcher do
  @moduledoc """
  A dispatcher based on subscription with filter set.
  """

  use GenServer

  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.EventFilter
  alias Citadel.EventFilterDispatcher.SubscriptionRegistry
  alias Citadel.EventFilterSubscription
  alias Citadel.SagaID
  alias Citadel.SubscribeEventFilter

  defmodule PushEvent do
    @moduledoc """
    An event to push an event from EventFilterDispatcher
    """

    @keys [:saga_id, :event, :subscriptions]
    @enforce_keys @keys
    defstruct @keys
  end

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Subscribe event filter synchronously.
  """
  @spec subscribe(SagaID.t(), module | nil, EventFilter.t(), meta :: term) ::
          EventFilterSubscription.t()
  def subscribe(id, module, event_filter, meta \\ nil) do
    subscribe_as_proxy(nil, id, module, event_filter, meta)
  end

  @doc """
  Subscribe event filter synchronously as a proxy.
  """
  @spec subscribe_as_proxy(
          proxy :: SagaID.t() | nil,
          SagaID.t(),
          module | nil,
          EventFilter.t(),
          meta :: term
        ) :: EventFilterSubscription.t()
  def subscribe_as_proxy(proxy_id, id, module, event_filter, meta \\ nil) do
    subscription = %EventFilterSubscription{
      proxy_saga_id: proxy_id,
      subscriber_saga_id: id,
      subscriber_saga_module: module,
      event_filter: event_filter,
      meta: meta
    }

    task =
      Task.async(fn ->
        Dispatcher.listen_event_body(%SubscribeEventFilter.Subscribed{
          subscription: subscription
        })

        Dispatcher.dispatch(
          Event.new(%SubscribeEventFilter{
            subscription: subscription
          })
        )

        receive do
          %Event{body: %SubscribeEventFilter.Subscribed{}} -> :ok
        end
      end)

    Task.await(task, 100)

    subscription
  end

  @impl true
  def init(_args) do
    Dispatcher.listen_all()
    {:ok, :ok}
  end

  @impl true
  def handle_info(%Event{body: %PushEvent{}}, state), do: {:noreply, state}

  def handle_info(%Event{} = event, state) do
    subscriptions = SubscriptionRegistry.subscriptions()

    subscriptions
    |> Enum.filter(fn subscription ->
      EventFilterSubscription.match?(subscription, event)
    end)
    |> Enum.group_by(fn subscription ->
      subscription.proxy_saga_id || subscription.subscriber_saga_id
    end)
    |> Enum.each(fn {saga_id, subscriptions} ->
      Dispatcher.dispatch(
        Event.new(%PushEvent{
          saga_id: saga_id,
          event: event,
          subscriptions: subscriptions
        })
      )
    end)

    {:noreply, state}
  end
end
