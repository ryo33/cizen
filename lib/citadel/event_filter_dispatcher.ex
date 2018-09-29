defmodule Citadel.EventFilterDispatcher do
  @moduledoc """
  A dispatcher based on subscription with filter set.
  """

  use GenServer

  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.EventFilter
  alias Citadel.EventFilterDispatcher.SubscriptionRegistry
  alias Citadel.EventFilterSubscribed
  alias Citadel.EventFilterSubscription
  alias Citadel.SagaID
  alias Citadel.SubscribeEventFilter

  defmodule PushEvent do
    @moduledoc """
    An event to push an event from EventFilterDispatcher
    """

    @keys [:event, :subscriptions]
    @enforce_keys @keys
    defstruct @keys
  end

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @spec subscribe(SagaID.t(), EventFilter.t(), meta :: term) :: EventFilterSubscription.t()
  def subscribe(id, event_filter, meta \\ nil) do
    subscription = %EventFilterSubscription{
      subscriber_saga_id: id,
      event_filter: event_filter,
      meta: meta
    }

    task =
      Task.async(fn ->
        Dispatcher.listen_event_body(%EventFilterSubscribed{
          subscription: subscription
        })

        Dispatcher.dispatch(
          Event.new(%SubscribeEventFilter{
            subscription: subscription
          })
        )

        receive do
          %Event{body: %EventFilterSubscribed{}} -> :ok
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
  def handle_info(%Event{} = event, state) do
    subscriptions = SubscriptionRegistry.subscriptions()

    subscriptions
    |> Enum.filter(fn subscription ->
      EventFilterSubscription.match?(subscription, event)
    end)
    |> Enum.group_by(fn subscription ->
      subscription.subscriber_saga_id
    end)
    |> Enum.each(fn {_, subscriptions} ->
      Dispatcher.dispatch(
        Event.new(%PushEvent{
          event: event,
          subscriptions: subscriptions
        })
      )
    end)

    {:noreply, state}
  end
end
