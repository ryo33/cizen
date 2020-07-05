defmodule Cizen.Dispatcher.Sender do
  @moduledoc false
  use GenServer

  def start_link(event) do
    GenServer.start_link(__MODULE__, event)
  end

  @spec register_preceding(pid, pid) :: :ok
  def register_preceding(sender, preceding) do
    GenServer.cast(sender, {:monitor, preceding})
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

  def init(event) do
    state = %{
      initialized?: false,
      preceding_downed?: false,
      waiting_nodes: nil,
      event: event,
      subscribers: MapSet.new()
    }

    {:ok, state}
  end

  def handle_info({:DOWN, _, _, _, _}, state) do
    {:noreply, %{state | preceding_downed?: true}, {:continue, :send_and_exit_if_fulfilled}}
  end

  def handle_continue(:send_and_exit_if_fulfilled, state) do
    if state.preceding_downed? and
         not is_nil(state.waiting_nodes) && Enum.empty?(state.waiting_nodes) do
      Enum.each(state.subscribers, fn subscriber ->
        send(subscriber, state.event)
      end)

      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:monitor, pid}, state) do
    if is_nil(pid) do
      {:noreply, %{state | preceding_downed?: true}}
    else
      Process.monitor(pid)
      {:noreply, state}
    end
  end

  def handle_cast(
        {:update, from_nodes, subscribers, following_nodes},
        state
      ) do
    state =
      state
      |> update_in([:waiting_nodes], fn nodes ->
        nodes =
          case nodes do
            nil -> MapSet.new()
            _ -> nodes
          end

        nodes
        |> MapSet.union(MapSet.new(following_nodes))
        |> MapSet.difference(MapSet.new(from_nodes))
      end)
      |> update_in([:subscribers], &MapSet.union(&1, MapSet.new(subscribers)))

    {:noreply, state, {:continue, :send_and_exit_if_fulfilled}}
  end
end
