defmodule Cizen.Dispatcher.Node do
  @moduledoc false
  use GenServer

  alias Cizen.Event
  alias Cizen.Filter
  alias Cizen.Filter.Code

  def initialize do
    :ets.new(__MODULE__, [:set, :public, :named_table, {:read_concurrency, true}])
  end

  def start_root_node do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def start_link do
    GenServer.start_link(__MODULE__, :ok)
  end

  @spec push(GenServer.server(), Event.t()) :: MapSet.t(pid)
  def push(node, event) do
    [{_, state}] = :ets.lookup(__MODULE__, GenServer.whereis(node))

    following_nodes =
      state.operations
      |> Enum.map(fn {operation, nodes} ->
        Map.get(nodes, Filter.eval(operation, event), [])
      end)
      |> List.flatten()
      |> Enum.uniq()

    Enum.reduce(following_nodes, state.subscribers, fn following_node, subscribers ->
      __MODULE__.push(following_node, event)
      |> MapSet.union(subscribers)
    end)
  end

  @spec put(GenServer.server(), Code.t(), pid) :: :ok
  def put(node \\ __MODULE__, code, subscriber) do
    run(node, {:update, code, {:put, subscriber}})
  end

  @spec delete(GenServer.server(), Code.t(), pid) :: :ok
  def delete(node \\ __MODULE__, code, subscriber) do
    run(node, {:update, code, {:delete, subscriber}})
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
    run(node, {:update, left, next})
    run(node, {:update, right, next})
  end

  defp run(node, {:update, operation, next}) do
    update_operation(node, operation, true, next)
  end

  defp run(node, {op, _} = command) when op in [:put, :delete] do
    :ok = GenServer.call(node, command)
  end

  defp update_operation(node, operation, value, next) do
    next_node = GenServer.call(node, {:update_operation, operation, value})
    run(next_node, next)
  end

  def init(_) do
    state = %{
      operations: %{},
      subscribers: MapSet.new(),
      monitors: %{}
    }

    :ets.insert(__MODULE__, {self(), state})
    {:ok, state}
  end

  def handle_info({:DOWN, ref, :process, downed_process, _}, state) do
    {monitor, state} = pop_in(state, [:monitors, ref])

    state =
      case monitor do
        [:subscribers] ->
          update_in(state.subscribers, &MapSet.delete(&1, downed_process))

        [:operations, operation, _value] = path ->
          {_, state} = pop_in(state, path)

          if Enum.empty?(state.operations[operation]) do
            {_, state} = pop_in(state, [:operations, operation])
            state
          else
            state
          end
      end

    sync(state)

    {:noreply, state, {:continue, :exit_if_empty}}
  end

  def handle_continue(:exit_if_empty, state) do
    if Enum.empty?(state.operations) and Enum.empty?(state.subscribers) do
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  defp sync(state) do
    :ets.insert(__MODULE__, {self(), Map.take(state, [:subscribers, :operations])})
  end

  defp sync_and_reply(state, reply \\ :ok) do
    sync(state)
    {:reply, reply, state}
  end

  def handle_call({:put, subscriber}, _from, state) do
    ref = Process.monitor(subscriber)

    state
    |> update_in([:subscribers], &MapSet.put(&1, subscriber))
    |> put_in([:monitors, ref], [:subscribers])
    |> sync_and_reply()
  end

  def handle_call({:delete, subscriber}, _from, state) do
    update_in(state.subscribers, &MapSet.delete(&1, subscriber))
    |> sync_and_reply()
  end

  def handle_call({:update_operation, operation, value}, _from, state) do
    values = Map.get(state.operations, operation, %{})
    next_node_path = [:operations, operation, value]

    {next_node, monitor} =
      case Map.get(values, value) do
        nil ->
          {:ok, node} = start_link()
          ref = Process.monitor(node)
          {node, %{ref => next_node_path}}

        node ->
          {node, %{}}
      end

    state
    |> put_in([:operations, operation], values)
    |> update_in([:monitors], &Map.merge(&1, monitor))
    |> put_in(next_node_path, next_node)
    |> sync_and_reply(next_node)
  end
end
