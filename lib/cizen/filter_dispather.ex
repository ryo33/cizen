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
       # ref => {filter, meta}
       subscriptions: %{},
       # ref => monitor_refs
       monitors: %{},
       # monitor_refs => ref
       lifetimes: %{}
     }}
  end

  @impl true
  def handle_cast({:listen, pid, event_filter, meta, lifetime_pids}, state) do
    lifetimes = [pid | lifetime_pids]

    monitor_refs = Enum.map(lifetimes, &Process.monitor/1)

    ref = make_ref()
    Application.get_env(:cizen, :event_router).put(event_filter, ref)

    subscriptions = Map.put(state.subscriptions, ref, {event_filter, {pid, meta}})

    monitors = Map.put(state.monitors, ref, monitor_refs)

    lifetimes =
      Enum.reduce(monitor_refs, state.lifetimes, fn monitor_ref, lifetimes ->
        Map.put(lifetimes, monitor_ref, ref)
      end)

    state = %{state | subscriptions: subscriptions, monitors: monitors, lifetimes: lifetimes}

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, monitor_ref, :process, _, _}, state) do
    {ref, lifetimes} = Map.pop(state.lifetimes, monitor_ref)

    if is_nil(ref) do
      {:noreply, state}
    else
      {filter, _meta} = state.subscriptions[ref]
      Application.get_env(:cizen, :event_router).delete(filter, ref)
      subscriptions = Map.delete(state.subscriptions, ref)
      {drops, monitors} = Map.pop(state.monitors, ref, [])
      lifetimes = Map.drop(lifetimes, drops)

      state = %{state | subscriptions: subscriptions, monitors: monitors, lifetimes: lifetimes}
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(%Event{} = event, state) do
    event
    |> Application.get_env(:cizen, :event_router).routes()
    |> Enum.map(fn ref -> state.subscriptions[ref] |> elem(1) end)
    |> Enum.group_by(
      fn {pid, meta} -> if is_nil(meta), do: pid, else: {pid, :proxied} end,
      fn {_, meta} -> meta end
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
