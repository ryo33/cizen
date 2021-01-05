defmodule Cizen.Dispatcher.NodeTest do
  use ExUnit.Case

  alias Cizen.Dispatcher.Node
  alias Cizen.Filter

  require Filter

  defmodule(TestEvent, do: defstruct([]))

  defp expand_node(node) do
    node
    |> :sys.get_state()
    |> update_in([:operations], fn operations ->
      Enum.reduce(operations, operations, fn {operation, _}, operations ->
        update_in(operations[operation], &expand_operation_nodes(&1))
      end)
    end)
  end

  defp expand_operation_nodes(nodes) do
    Enum.reduce(nodes, nodes, fn {value, child}, nodes ->
      update_in(nodes, [value], fn _ -> expand_node(child) end)
    end)
  end

  describe "push" do
  end

  describe "put" do
    test "put true" do
      subscriber = self()
      {:ok, node} = Node.start_link()

      Node.put(node, true, subscriber)

      subscribers = MapSet.new([subscriber])

      assert %{
               operations: %{},
               subscribers: ^subscribers
             } = :sys.get_state(node)
    end

    test "put operation" do
      # subscriber = self()
      # {:ok, node} = Node.start_link()
      # :erlang.trace(node, true, [:send])

      # Node.put(node, {:<>, ["a", "b"]}, subscriber)

      # assert_gen_cast_from(node, {:run, {:put_subscriber, subscriber}})
    end

    test "put :==" do
      # subscriber = self()
      # {:ok, node} = Node.start_link()
      # :erlang.trace(node, true, [:send])

      # Node.put(node, {:==, [{:access, [:key]}, "a"]}, subscriber)
      # assert_gen_cast_from(node, {:run, {:put_subscriber, subscriber}})
    end

    test "put not" do
      # subscriber = self()
      # {:ok, node} = Node.start_link()
      # :erlang.trace(node, true, [:send])

      # Node.put(node, {:not, [{:access, [:key]}]}, subscriber)
      # assert_gen_cast_from(node, {:run, {:put_subscriber, subscriber}})
    end

    test "put and" do
      # subscriber = self()
      # {:ok, node} = Node.start_link()
      # :erlang.trace(node, true, [:send])

      # Node.put(node, {:and, ["a", {:and, ["b", "c"]}]}, subscriber)

      # a_node =
      #   assert_gen_cast_from(
      #     node,
      #     {:run, {:update, {:and, ["b", "c"]}, {:put_subscriber, subscriber}}}
      #   )

      # :erlang.trace(a_node, true, [:send])
      # b_node = assert_gen_cast_from(a_node, {:run, {:update, "c", {:put_subscriber, subscriber}}})
      # :erlang.trace(b_node, true, [:send])
      # assert_gen_cast_from(b_node, {:run, {:put_subscriber, subscriber}})
    end

    test "put or" do
      # subscriber = self()
      # {:ok, node} = Node.start_link()
      # :erlang.trace(node, true, [:send])

      # Node.put(node, {:or, ["a", {:or, ["b", "c"]}]}, subscriber)
      # assert_gen_cast_from(node, {:run, {:put_subscriber, subscriber}})
    end
  end

  describe "delete" do
    test "delete true" do
      subscriber = self()
      {:ok, node} = Node.start_link()
      Node.put(node, true, subscriber)
      Node.delete(node, true, subscriber)

      actual = :sys.get_state(node)

      expected = %{
        operations: %{},
        subscribers: MapSet.new()
      }

      assert expected.operations == actual.operations
      assert expected.subscribers == actual.subscribers
    end

    test "delete operation" do
      # subscriber = self()
      # {:ok, node} = Node.start_link()
      # :erlang.trace(node, true, [:send])

      # Node.put(node, {:<>, ["a", "b"]}, subscriber)
      # Node.delete(node, {:<>, ["a", "b"]}, subscriber)
      # assert_gen_cast_from(node, {:run, {:delete_subscriber, subscriber}})
    end
  end

  test "deletes the subscriber from subscribers when it downed" do
    subscriber1 =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    subscriber2 = spawn(fn -> :timer.sleep(:infinity) end)

    {:ok, node} = Node.start_link()
    before_set = MapSet.new([subscriber1, subscriber2])
    after_set = MapSet.new([subscriber2])

    Node.put(node, true, subscriber1)
    Node.put(node, true, subscriber2)
    assert %{subscribers: ^before_set} = expand_node(node)
    :erlang.trace(node, true, [:receive])
    Process.exit(subscriber1, :kill)
    assert_receive {:trace, _, _, {:DOWN, _, _, ^subscriber1, _}}
    assert %{subscribers: ^after_set} = expand_node(node)
  end

  test "deletes operation value when the next node downed" do
    subscriber1 = spawn(fn -> :timer.sleep(:infinity) end)
    subscriber2 = spawn(fn -> :timer.sleep(:infinity) end)
    {:ok, node} = Node.start_link()
    %{code: code} = Filter.new(fn a -> a == "a" or a == "b" end)
    Node.put(node, code, subscriber1)
    Node.put(node, code, subscriber2)

    get_a_node = fn ->
      node
      |> :sys.get_state()
      |> get_in([:operations, {:access, []}, "a"])
    end

    a_node = get_a_node.()
    GenServer.stop(a_node)
    assert nil == get_a_node.()
  end

  test "deletes operation when all operation value have deleted" do
    subscriber = spawn(fn -> :timer.sleep(:infinity) end)
    {:ok, node} = Node.start_link()
    %{code: code} = Filter.new(fn a -> a == "a" or a == "b" end)
    Node.put(node, true, subscriber)
    Node.put(node, code, subscriber)

    get_operation = fn ->
      node
      |> :sys.get_state()
      |> get_in([:operations, {:access, []}])
    end

    get_next_node = fn key ->
      get_in(get_operation.(), [key])
    end

    assert %{} = get_operation.()
    GenServer.stop(get_next_node.("a"))
    GenServer.stop(get_next_node.("b"))
    assert nil == get_operation.()
  end

  test "exits if all subscribers have downed and operations is empty" do
    subscriber =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    {:ok, node} = Node.start_link()
    Process.monitor(node)
    %{code: code} = Filter.new(fn a -> a == "a" or a == "b" end)
    Node.put(node, true, subscriber)
    Node.put(node, code, subscriber)

    send(subscriber, :stop)
    assert_receive {:DOWN, _, _, ^node, _}
  end
end
