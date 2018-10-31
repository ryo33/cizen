defmodule Cizen.DefaultEventRouter do
  @moduledoc """
  The default event router for `Cizen.EventDispatcher`.
  """

  use GenServer
  @behaviour Cizen.EventRouter

  alias Cizen.EventFilter

  @impl Cizen.EventRouter
  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl Cizen.EventRouter
  def put(subscription) do
    GenServer.cast(__MODULE__, {:put, subscription})
  end

  @impl Cizen.EventRouter
  def delete(subscription) do
    GenServer.cast(__MODULE__, {:delete, subscription})
  end

  @impl Cizen.EventRouter
  def routes(event) do
    GenServer.call(__MODULE__, {:routes, event})
  end

  @impl GenServer
  def init(_) do
    {:ok, MapSet.new([])}
  end

  @impl GenServer
  def handle_cast({:put, subscription}, state) do
    {:noreply, MapSet.put(state, subscription)}
  end

  @impl GenServer
  def handle_cast({:delete, subscription}, state) do
    {:noreply, MapSet.delete(state, subscription)}
  end

  @impl GenServer
  def handle_call({:routes, event}, _from, state) do
    routes =
      Enum.filter(state, fn {event_filter, _meta} ->
        EventFilter.test(event_filter, event)
      end)

    {:reply, routes, state}
  end
end
