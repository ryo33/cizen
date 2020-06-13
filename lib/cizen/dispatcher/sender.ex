defmodule Cizen.Dispatcher.Sender do
  use GenServer

  alias Cizen.Event

  def start_link(preceding) do
    GenServer.start_link(__MODULE__, preceding)
  end

  @spec wait_node(pid, GenServer.server()) :: :ok
  def wait_node(sender, node) do
    GenServer.cast(
      sender,
      {:update, [], [], [node]}
    )
  end

  @spec put_subscribers_and_following_nodes(pid, pid, list(pid), list(pid)) :: :ok
  def put_subscribers_and_following_nodes(sender, from_node, subscribers, following_nodes) do
    GenServer.cast(
      sender,
      {:update, [from_node], subscribers, following_nodes}
    )
  end

  @spec put_event(pid, Event.t()) :: :ok
  def put_event(sender, event) do
    GenServer.cast(sender, {:put_event, event})
  end

  def init(preceding) do
    unless is_nil(preceding), do: Process.monitor(preceding)

    state = %{
      preceding_downed: is_nil(preceding),
      waiting_nodes: MapSet.new([]),
      event: nil,
      subscribers: MapSet.new([])
    }

    {:ok, state}
  end

  def handle_info({:DOWN, _, _, _, _}, state) do
    {:noreply, %{state | preceding_downed: true}, {:continue, :send_and_exit_if_fulfilled}}
  end

  def handle_continue(:send_and_exit_if_fulfilled, state) do
    if state.preceding_downed and not is_nil(state.event) and Enum.empty?(state.waiting_nodes) do
      Enum.map(state.subscribers, fn subscriber ->
        send(subscriber, state.event)
      end)

      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:put_event, event}, state) do
    {:noreply, %{state | event: event}, {:continue, :send_and_exit_if_fulfilled}}
  end

  def handle_cast(
        {:update, from_nodes, subscribers, following_nodes},
        state
      ) do
    state =
      state
      |> update_in([:waiting_nodes], fn nodes ->
        nodes
        |> MapSet.union(MapSet.new(following_nodes))
        |> MapSet.difference(MapSet.new(from_nodes))
      end)
      |> update_in([:subscribers], &MapSet.union(&1, MapSet.new(subscribers)))

    {:noreply, state, {:continue, :send_and_exit_if_fulfilled}}
  end
end
