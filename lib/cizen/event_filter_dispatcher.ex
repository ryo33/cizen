defmodule Cizen.EventFilterDispatcher do
  @moduledoc """
  A dispatcher based on subscription with filter set.
  """

  use GenServer

  alias Cizen.CizenSagaRegistry
  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.EventFilter
  alias Cizen.SagaID

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
  @spec subscribe(SagaID.t(), EventFilter.t(), meta :: term) :: __MODULE__.Subscription.t()
  def subscribe(id, event_filter, meta \\ nil) do
    subscribe_as_proxy(nil, id, nil, event_filter, meta)
  end

  @doc """
  Subscribe event filter synchronously as a proxy.
  """
  @spec subscribe_as_proxy(
          proxy :: SagaID.t() | nil,
          SagaID.t(),
          SagaID.t() | nil,
          EventFilter.t(),
          meta :: term
        ) :: __MODULE__.Subscription.t()
  def subscribe_as_proxy(proxy_id, id, lifetime_id, event_filter, meta \\ nil) do
    subscription = %__MODULE__.Subscription{
      proxy_saga_id: proxy_id,
      subscriber_saga_id: id,
      lifetime_saga_id: lifetime_id,
      event_filter: event_filter,
      meta: meta
    }

    event =
      Event.new(id, %__MODULE__.Subscribe{
        subscription: subscription
      })

    task =
      Task.async(fn ->
        Dispatcher.listen_event_body(%__MODULE__.Subscribe.Subscribed{
          subscribe_id: event.id
        })

        Dispatcher.dispatch(event)

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
       # subscription => refs
       subscriptions: %{}
     }}
  end

  @impl true
  def handle_info(%Event{body: %PushEvent{}}, state), do: {:noreply, state}

  def handle_info(%Event{body: %__MODULE__.Subscribe{subscription: subscription}} = event, state) do
    lifetimes = [subscription.subscriber_saga_id]

    lifetimes =
      if is_nil(subscription.lifetime_saga_id) do
        lifetimes
      else
        [subscription.lifetime_saga_id | lifetimes]
      end

    pids =
      Enum.map(lifetimes, fn lifetime ->
        case CizenSagaRegistry.get_pid(lifetime) do
          {:ok, pid} -> pid
          _ -> nil
        end
      end)

    state =
      if Enum.all?(pids, &is_pid/1) do
        refs =
          pids
          |> Enum.map(&Process.monitor/1)

        subscriptions = Map.put(state.subscriptions, subscription, refs)

        refs =
          Enum.reduce(refs, state.refs, fn ref, refs ->
            Map.put(refs, ref, subscription)
          end)

        %{state | refs: refs, subscriptions: subscriptions}
      else
        state
      end

    Dispatcher.dispatch(Event.new(nil, %__MODULE__.Subscribe.Subscribed{subscribe_id: event.id}))

    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, _, _}, state) do
    {subscription, refs} = Map.pop(state.refs, ref)
    {drop, subscriptions} = Map.pop(state.subscriptions, subscription)

    refs =
      if not is_nil(drop) and length(drop) > 1 do
        Map.drop(refs, drop)
      else
        refs
      end

    state = %{state | refs: refs, subscriptions: subscriptions}
    {:noreply, state}
  end

  def handle_info(%Event{} = event, state) do
    state.subscriptions
    |> Map.keys()
    |> Enum.filter(fn subscription ->
      __MODULE__.Subscription.match?(subscription, event)
    end)
    |> Enum.group_by(fn subscription ->
      subscription.proxy_saga_id || subscription.subscriber_saga_id
    end)
    |> Enum.each(fn {saga_id, subscriptions} ->
      Dispatcher.dispatch(
        Event.new(nil, %PushEvent{
          saga_id: saga_id,
          event: event,
          subscriptions: subscriptions
        })
      )
    end)

    {:noreply, state}
  end
end
