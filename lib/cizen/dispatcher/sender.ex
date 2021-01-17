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

  # Passes the token to the next sender.
  def allow_to_send(sender) do
    GenServer.cast(sender, :allow_to_send)
  end

  defp reset(state) do
    state
    |> Map.put(:event, nil)
    |> Map.put(:allowed_to_send?, false)
    |> Map.put(:destinations, nil)
  end

  def init({name, root_node, next_sender}) do
    state =
      %{
        name: name,
        root_node: root_node,
        next_sender: next_sender,
        event_queue: :queue.new()
      }
      |> reset()

    {:ok, state}
  end

  def handle_continue(:try_dequeue_event, %{event: nil, event_queue: queue} = state) do
    case :queue.out(queue) do
      {{:value, event}, queue} ->
        state = %{state | event: event, event_queue: queue}

        destinations = Node.push(state.root_node, event)

        state = put_in(state.destinations, destinations)
        {:noreply, state, {:continue, :send_if_fulfilled}}

      _ ->
        {:noreply, state}
    end
  end

  def handle_continue(:try_dequeue_event, state), do: {:noreply, state}

  def handle_continue(:send_if_fulfilled, state) do
    if not is_nil(state.event) and state.allowed_to_send? do
      Enum.each(state.destinations, fn pid ->
        send(pid, state.event)
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
end
