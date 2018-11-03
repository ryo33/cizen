defmodule Cizen.DefaultEventRouter do
  @moduledoc """
  The default event router for `Cizen.EventDispatcher`.
  """

  use GenServer
  @behaviour Cizen.EventRouter

  alias Cizen.DefaultEventRouter.Node

  @impl Cizen.EventRouter
  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl Cizen.EventRouter
  def put(filter, ref) do
    GenServer.cast(__MODULE__, {:put, filter, ref})
  end

  @impl Cizen.EventRouter
  def delete(filter, ref) do
    GenServer.cast(__MODULE__, {:delete, filter, ref})
  end

  @impl Cizen.EventRouter
  def routes(event) do
    GenServer.call(__MODULE__, {:routes, event})
  end

  @impl GenServer
  def init(_) do
    {:ok, Node.new()}
  end

  @impl GenServer
  def handle_cast({:put, filter, ref}, state) do
    {:noreply, Node.put(state, filter.code, ref)}
  end

  @impl GenServer
  def handle_cast({:delete, filter, ref}, state) do
    {:noreply, Node.delete(state, filter.code, ref)}
  end

  @impl GenServer
  def handle_call({:routes, event}, _from, state) do
    routes =
      state
      |> Node.get(event)
      |> MapSet.to_list()

    {:reply, routes, state}
  end
end
