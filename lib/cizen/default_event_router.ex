defmodule Cizen.DefaultEventRouter do
  @moduledoc """
  The default event router for `Cizen.EventDispatcher`.
  """

  use GenServer
  @behaviour Cizen.EventRouter

  alias Cizen.Filter

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
    {:ok, MapSet.new([])}
  end

  @impl GenServer
  def handle_cast({:put, filter, ref}, state) do
    {:noreply, MapSet.put(state, {filter, ref})}
  end

  @impl GenServer
  def handle_cast({:delete, filter, ref}, state) do
    {:noreply, MapSet.delete(state, {filter, ref})}
  end

  @impl GenServer
  def handle_call({:routes, event}, _from, state) do
    routes =
      state
      |> Enum.filter(fn {filter, _ref} ->
        Filter.match?(filter, event)
      end)
      |> Enum.map(fn {_filter, ref} -> ref end)

    {:reply, routes, state}
  end
end
