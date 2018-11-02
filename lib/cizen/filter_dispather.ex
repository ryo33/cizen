defmodule Cizen.FilterDispatcher do
  @moduledoc """
  A dispatcher based on subscription with filter set.

  `Cizen.DefaultEventRouter` is used for event routing.
  You can customize this in a config:

      use Mix.Config
      config :cizen, event_router: YourEventRouter
  """

  use GenServer

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.Filter

  defmodule PushEvent do
    @moduledoc """
    An event to push an event with meta values.
    """

    @keys [:event, :metas]
    @enforce_keys @keys
    defstruct @keys
  end

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  listen event filter.
  """
  @spec listen(Filter.t(), lifetime_pids :: [pid]) :: :ok
  def listen(event_filter, lifetime_pids \\ []) do
    GenServer.cast(__MODULE__, {:listen, self(), event_filter, nil, lifetime_pids})
  end

  @doc """
  listen event filter with meta.
  """
  @spec listen_with_meta(Filter.t(), meta :: term, lifetime_pids :: [pid]) :: :ok
  def listen_with_meta(event_filter, meta, lifetime_pids \\ []) do
    GenServer.cast(__MODULE__, {:listen, self(), event_filter, meta, lifetime_pids})
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
  def handle_cast({:listen, pid, event_filter, meta, lifetime_pids}, state) do
    lifetimes = [pid | lifetime_pids]

    refs = Enum.map(lifetimes, &Process.monitor/1)

    subscription = {event_filter, {pid, meta}}
    Application.get_env(:cizen, :event_router).put(subscription)

    subscriptions = Map.put(state.subscriptions, subscription, refs)

    refs =
      Enum.reduce(refs, state.refs, fn ref, refs ->
        Map.put(refs, ref, subscription)
      end)

    state = %{state | refs: refs, subscriptions: subscriptions}

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _, _}, state) do
    {subscription, refs} = Map.pop(state.refs, ref)

    if is_nil(subscription) do
      {:noreply, state}
    else
      Application.get_env(:cizen, :event_router).delete(subscription)
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
  end

  @impl true
  def handle_info(%Event{} = event, state) do
    event
    |> Application.get_env(:cizen, :event_router).routes()
    |> Enum.group_by(
      fn {_, {pid, meta}} -> if is_nil(meta), do: pid, else: {pid, :proxied} end,
      fn {_, {_, meta}} -> meta end
    )
    |> Enum.each(fn {dest, metas} ->
      case dest do
        {pid, :proxied} ->
          event =
            Event.new(nil, %PushEvent{
              event: event,
              metas: metas
            })

          Dispatcher.dispatch(event)
          send(pid, event)

        pid ->
          send(pid, event)
      end
    end)

    {:noreply, state}
  end
end
