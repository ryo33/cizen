defmodule Cizen.Dispatcher.Sender do
  @moduledoc false
  use GenServer

  alias Cizen.Dispatcher.Node

  def start_link(opts) do
    root_node = Keyword.get(opts, :root_node, Node)
    next_sender = Keyword.fetch!(opts, :next_sender)
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, {name, root_node, next_sender}, name: name)
  end

  def push(sender, event) do
    GenServer.cast(sender, {:push, event})
  end

  def allow_to_send(sender) do
    GenServer.cast(sender, :allow_to_send)
  end

  @spec put_subscribers_and_following_nodes(pid, pid, list(pid), list(pid)) :: :ok
  def put_subscribers_and_following_nodes(sender, from_node, subscribers, following_nodes) do
    GenServer.cast(sender, {:update, from_node, subscribers, following_nodes})
  end

  defp reset(state) do
    state
    |> Map.put(:event, nil)
    |> Map.put(:waiting_nodes, MapSet.new([state.root_node]))
    |> Map.put(:subscribers, MapSet.new())
  end

  def init({name, root_node, next_sender}) do
    state =
      %{
        name: name,
        root_node: root_node,
        next_sender: next_sender,
        allowed_to_send?: false,
        event_queue: :queue.new()
      }
      |> reset()

    {:ok, state}
  end

  def handle_continue(:try_dequeue_event, %{event: nil, event_queue: queue} = state) do
    case :queue.out(queue) do
      {{:value, event}, queue} ->
        state = %{state | event: event, event_queue: queue}
        Node.push(state.root_node, state.name, event)
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_continue(:try_dequeue_event, state), do: {:noreply, state}

  def handle_continue(:send_if_fulfilled, state) do
    if state.allowed_to_send? and MapSet.size(state.waiting_nodes) == 0 do
      Enum.each(state.subscribers, fn subscriber ->
        send(subscriber, state.event)
      end)

      allow_to_send(state.next_sender)

      {:noreply, state |> reset(), {:continue, :try_dequeue_event}}
    else
      {:noreply, state}
    end
  end

  def handle_cast(:allow_to_send, state) do
    state = %{state | allowed_to_send?: true}
    {:noreply, state, {:continue, :send_if_fulfilled}}
  end

  def handle_cast({:push, event}, state) do
    state = %{state | event_queue: :queue.in(event, state.event_queue)}
    {:noreply, state, {:continue, :try_dequeue_event}}
  end

  def handle_cast({:update, from_node, subscribers, following_nodes}, state) do
    state =
      state
      |> update_in([:waiting_nodes], fn nodes ->
        nodes
        |> MapSet.union(MapSet.new(following_nodes))
        |> MapSet.delete(from_node)
      end)
      |> update_in([:subscribers], &MapSet.union(&1, MapSet.new(subscribers)))

    {:noreply, state, {:continue, :send_if_fulfilled}}
  end
end
