defmodule Cizen.DefaultEventRouter.Node do
  @moduledoc false

  alias Cizen.Filter

  defstruct subscriptions: MapSet.new([]),
            operations: %{}

  def new, do: %__MODULE__{}

  def put(node, code, subscription) do
    run(node, {:update, code, {:put_subscription, subscription}})
  end

  def delete(node, code, subscription) do
    run(node, {:update, code, {:delete_subscription, subscription}})
  end

  def get(node, struct) do
    %__MODULE__{subscriptions: subscriptions, operations: operations} = node

    Enum.reduce(operations, subscriptions, fn {operation, nodes}, subscriptions ->
      value = Filter.eval(operation, struct)
      node = Map.get(nodes, value, new())
      MapSet.union(subscriptions, get(node, struct))
    end)
  end

  defp run(node, {:update, true, next}) do
    run(node, next)
  end

  defp run(node, {:update, {:==, [operation, value]}, next})
       when not is_tuple(value) or tuple_size(value) != 2 do
    update_operation(node, operation, value, next)
  end

  defp run(node, {:update, {:==, [value, operation]}, next})
       when not is_tuple(value) or tuple_size(value) != 2 do
    update_operation(node, operation, value, next)
  end

  defp run(node, {:update, {:not, [operation]}, next}) do
    update_operation(node, operation, false, next)
  end

  defp run(node, {:update, {:and, [left, right]}, next}) do
    run(node, {:update, left, {:update, right, next}})
  end

  defp run(node, {:update, {:or, [left, right]}, next}) do
    node
    |> run({:update, left, next})
    |> run({:update, right, next})
  end

  defp run(node, {:update, operation, next}) do
    update_operation(node, operation, true, next)
  end

  defp run(node, {:put_subscription, subscription}) do
    update_in(node.subscriptions, &MapSet.put(&1, subscription))
  end

  defp run(node, {:delete_subscription, subscription}) do
    update_in(node.subscriptions, &MapSet.delete(&1, subscription))
  end

  defp update_operation(node, operation, value, next) do
    values = Map.get(node.operations, operation, %{})

    next_node =
      values
      |> Map.get(value, new())
      |> run(next)

    node = put_in(node.operations[operation], values)
    put_in(node.operations[operation][value], next_node)
  end
end
