defmodule Cizen.Dispatcher.Node do
  use GenServer

  alias Cizen.Dispatcher.Sender
  alias Cizen.Event
  alias Cizen.Filter.Code

  def start_root_node do
    GenServer.start_link(__MODULE__, :ok, name: {:global, Cizen.Dispatcher.RootNode})
  end

  def start_link do
    GenServer.start_link(__MODULE__, :ok)
  end

  @spec push(GenServer.server(), pid, Event.t()) :: :ok
  def push(node, sender, event) do
    GenServer.cast(node, {:push, node, sender, event})
  end

  @spec put(GenServer.server(), Code.t(), pid) :: :ok
  def put(node, code, subscriber) do
    GenServer.cast(node, {:put, code, subscriber})
  end

  @spec delete(GenServer.server(), Code.t(), pid) :: :ok
  def delete(node, code, subscriber) do
    GenServer.cast(node, {:delete, code, subscriber})
  end

  def init(_) do
    state = %{
      operations: %{},
      subscribers: MapSet.new()
    }

    {:ok, state}
  end

  def handle_cast({:push, from_node, sender, event}, state) do
    following_nodes =
      Enum.map(state.operations, fn {_, values} ->
        Enum.map(values, fn {_, following_node} -> following_node end)
      end)
      |> List.flatten()

    Sender.put_subscribers_and_following_nodes(
      sender,
      from_node,
      MapSet.to_list(state.subscribers),
      following_nodes
    )

    Enum.each(following_nodes, fn following_node ->
      __MODULE__.push(following_node, sender, event)
    end)

    {:noreply, state}
  end

  def handle_cast({:put, code, subscriber}, state) do
    {:noreply, run(state, {:update, code, {:put_subscriber, subscriber}})}
  end

  def handle_cast({:delete, code, subscriber}, state) do
    {:noreply, run(state, {:update, code, {:delete_subscriber, subscriber}})}
  end

  def handle_cast({:run, command}, state) do
    {:noreply, run(state, command)}
  end

  defp run_command(node, command) do
    GenServer.cast(node, {:run, command})
  end

  defp run(state, {:update, true, next}) do
    run(state, next)
  end

  defp run(state, {:update, {:==, [operation, value]}, next})
       when not is_tuple(value) or tuple_size(value) != 2 do
    update_operation(state, operation, value, next)
  end

  defp run(state, {:update, {:==, [value, operation]}, next})
       when not is_tuple(value) or tuple_size(value) != 2 do
    update_operation(state, operation, value, next)
  end

  defp run(state, {:update, {:not, [operation]}, next}) do
    update_operation(state, operation, false, next)
  end

  defp run(state, {:update, {:and, [left, right]}, next}) do
    run(state, {:update, left, {:update, right, next}})
  end

  defp run(state, {:update, {:or, [left, right]}, next}) do
    state
    |> run({:update, left, next})
    |> run({:update, right, next})
  end

  defp run(state, {:update, operation, next}) do
    update_operation(state, operation, true, next)
  end

  defp run(state, {:put_subscriber, subscriber}) do
    update_in(state.subscribers, &MapSet.put(&1, subscriber))
  end

  defp run(state, {:delete_subscriber, subscriber}) do
    update_in(state.subscribers, &MapSet.delete(&1, subscriber))
  end

  defp update_operation(state, operation, value, next) do
    values = Map.get(state.operations, operation, %{})

    next_node =
      case Map.get(values, value) do
        nil ->
          {:ok, node} = start_link()
          node

        node ->
          node
      end

    run_command(next_node, next)

    state = put_in(state.operations[operation], values)
    put_in(state.operations[operation][value], next_node)
  end
end
