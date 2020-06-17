defmodule Cizen.Dispatcher.Node do
  use GenServer

  alias Cizen.Dispatcher.Sender
  alias Cizen.Event
  alias Cizen.Filter
  alias Cizen.Filter.Code

  def start_root_node do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def start_link do
    GenServer.start_link(__MODULE__, :ok)
  end

  def expand(node) do
    :sys.get_state(node)
    |> update_in([:operations], fn operations ->
      Enum.reduce(operations, operations, fn {operation, _}, operations ->
        operations
        |> update_in([operation], fn nodes ->
          Enum.reduce(nodes, nodes, fn {value, child}, nodes ->
            update_in(nodes, [value], fn _ -> expand(child) end)
          end)
        end)
      end)
    end)
  end

  @spec push(GenServer.server(), pid, Event.t()) :: :ok
  def push(node \\ __MODULE__, sender, event) do
    GenServer.cast(node, {:push, node, sender, event})
  end

  @spec put(GenServer.server(), Code.t(), pid) :: :ok
  def put(node \\ __MODULE__, code, subscriber) do
    GenServer.cast(node, {:put, code, subscriber})
  end

  @spec delete(GenServer.server(), Code.t(), pid) :: :ok
  def delete(node \\ __MODULE__, code, subscriber) do
    GenServer.cast(node, {:delete, code, subscriber})
  end

  def init(_) do
    state = %{
      operations: %{},
      subscribers: MapSet.new()
    }

    {:ok, state}
  end

  def handle_info({:DOWN, _, _, subscriber_or_downed_node, _}, state) do
    state =
      if MapSet.member?(state.subscribers, subscriber_or_downed_node) do
        update_in(state.subscribers, &MapSet.delete(&1, subscriber_or_downed_node))
      else
        update_in(state.operations, fn operations ->
          Enum.reduce(operations, %{}, fn {operation, nodes}, operations ->
            nodes =
              nodes
              |> Enum.filter(fn {_, node} -> node !== subscriber_or_downed_node end)
              |> Enum.into(%{})
            if Enum.empty?(nodes) do
              operations
            else
              put_in(operations, [operation], nodes)
            end
          end)
        end)
      end

    {:noreply, state, {:continue, :exit_if_empty}}
  end

  def handle_continue(:exit_if_empty, state) do
    if Enum.empty?(state.operations) and Enum.empty?(state.subscribers) do
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:push, from_node, sender, event}, state) do
    following_nodes =
      Enum.reduce(state.operations, MapSet.new(), fn {operation, nodes}, following_nodes ->
        value = Filter.eval(operation, event)

        case Map.get(nodes, value) do
          nil -> following_nodes
          following_node -> MapSet.put(following_nodes, following_node)
        end
      end)

    Sender.put_subscribers_and_following_nodes(
      sender,
      from_node,
      MapSet.to_list(state.subscribers),
      MapSet.to_list(following_nodes)
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
    Process.monitor(subscriber)
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
          Process.monitor(node)
          node

        node ->
          node
      end
    run_command(next_node, next)

    state = put_in(state.operations[operation], values)
    put_in(state.operations[operation][value], next_node)
  end
end
