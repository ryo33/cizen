defmodule Citadel.EventFilterDispatcher do
  @moduledoc """
  A dispatcher based on subscription with filter set.
  """

  use GenServer

  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.EventFilter
  alias Citadel.SagaID
  alias Citadel.SagaRegistry

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
          __MODULE__.Subscription.t()
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
        ) :: __MODULE__.Subscription.t()
  def subscribe_as_proxy(proxy_id, id, module, event_filter, meta \\ nil) do
    subscription = %__MODULE__.Subscription{
      proxy_saga_id: proxy_id,
      subscriber_saga_id: id,
      subscriber_saga_module: module,
      event_filter: event_filter,
      meta: meta
    }

    task =
      Task.async(fn ->
        Dispatcher.listen_event_body(%__MODULE__.Subscribe.Subscribed{
          subscription: subscription
        })

        Dispatcher.dispatch(
          Event.new(%__MODULE__.Subscribe{
            subscription: subscription
          })
        )

        receive do
          %Event{body: %__MODULE__.Subscribe.Subscribed{}} -> :ok
        end
      end)

    Task.await(task, 100)

    subscription
  end

  @impl true
  def init(_args) do
    Dispatcher.listen_all()

    {:ok,
     %{
       # ref => subscription
       refs: %{},
       subscriptions: MapSet.new([])
     }}
  end

  @impl true
  def handle_info(%Event{body: %PushEvent{}}, state), do: {:noreply, state}

  def handle_info(%Event{body: %__MODULE__.Subscribe{subscription: subscription}}, state) do
    state =
      case SagaRegistry.resolve_id(subscription.subscriber_saga_id) do
        {:ok, pid} ->
          ref = Process.monitor(pid)
          refs = Map.put(state.refs, ref, subscription)
          subscriptions = MapSet.put(state.subscriptions, subscription)

          Dispatcher.dispatch(
            Event.new(%__MODULE__.Subscribe.Subscribed{subscription: subscription})
          )

          %{state | refs: refs, subscriptions: subscriptions}

        :error ->
          state
      end

    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, _, _}, state) do
    {subscription, refs} = Map.pop(state.refs, ref)
    subscriptions = MapSet.delete(state.subscriptions, subscription)
    state = %{state | refs: refs, subscriptions: subscriptions}
    {:noreply, state}
  end

  def handle_info(%Event{} = event, state) do
    state.subscriptions
    |> Enum.filter(fn subscription ->
      __MODULE__.Subscription.match?(subscription, event)
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
