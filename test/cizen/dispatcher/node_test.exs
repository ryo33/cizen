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
      # {:ok, node} = Node.start_link()

      # Node.put(node, {:<>, ["a", "b"]}, subscriber)

      # assert_gen_cast_from(node, {:run, {:put_subscriber, subscriber}})
    end

    test "put :==" do
      subscriber = self()
      {:ok, node} = Node.start_link()

      Node.put(node, {:==, [{:access, [:key]}, "a"]}, subscriber)

      assert %{
               {:access, [:key]} => %{
                 "a" => next_node
               }
             } = :sys.get_state(node).operations

      assert :sys.get_state(next_node).subscribers == MapSet.new([subscriber])
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

    test "does not receive nothing after put :or" do
      subscriber = self()
      {:ok, node} = Node.start_link()

      %{code: code} = Filter.new(fn a -> a == "a" or a == "b" end)
      Node.put(node, code, subscriber)
      refute_receive _
    end
  end

  test "deletes the subscriber from subscribers when it downed" do
    subscriber1 =
      spawn_link(fn ->
        receive do
          :stop -> :ok
        end
      end)

    subscriber2 = spawn_link(fn -> :timer.sleep(:infinity) end)

    {:ok, node} = Node.start_link()
    before_set = MapSet.new([subscriber1, subscriber2])
    after_set = MapSet.new([subscriber2])

    Node.put(node, true, subscriber1)
    Node.put(node, true, subscriber2)
    assert %{subscribers: ^before_set} = expand_node(node)
    :erlang.trace(node, true, [:receive])
    send(subscriber1, :stop)
    assert_receive {:trace, _, _, {:DOWN, _, _, ^subscriber1, _}}
    assert %{subscribers: ^after_set} = expand_node(node)
  end

  test "deletes operation value when the next node downed" do
    subscriber =
      spawn_link(fn ->
        receive do
          :stop -> :ok
        end
      end)

    {:ok, node} = Node.start_link()
    %{code: code} = Filter.new(fn a -> a == "a" end)

    Node.put(node, code, subscriber)

    get_a_node = fn ->
      node
      |> :sys.get_state()
      |> get_in([:operations, {:access, []}, "a"])
    end

    assert not is_nil(get_a_node.())
    send(subscriber, :stop)
    :timer.sleep(100)
    assert is_nil(get_a_node.())
  end

  test "deletes operation when all operation value have deleted" do
    subscriber1 =
      spawn_link(fn ->
        receive do
          :stop -> :ok
        end
      end)

    subscriber2 =
      spawn_link(fn ->
        receive do
          :stop -> :ok
        end
      end)

    {:ok, node} = Node.start_link()
    %{code: code1} = Filter.new(fn a -> a == "a" end)
    %{code: code2} = Filter.new(fn a -> a == "b" end)
    Node.put(node, code1, subscriber1)
    Node.put(node, code2, subscriber2)

    get_operation = fn ->
      node
      |> :sys.get_state()
      |> get_in([:operations, {:access, []}])
    end

    assert %{} = get_operation.()

    send(subscriber1, :stop)
    :timer.sleep(50)
    assert %{} = get_operation.()

    send(subscriber2, :stop)
    :timer.sleep(50)
    assert nil == get_operation.()
  end

  test "exits when all subscribers have downed and operations is empty" do
    subscriber =
      spawn_link(fn ->
        receive do
          :stop -> :ok
        end
      end)

    {:ok, parent_node} = Node.start_link()
    {:ok, node} = Node.start_link(parent_node)
    Process.monitor(node)
    %{code: code} = Filter.new(fn a -> a == "a" end)
    Node.put(node, code, subscriber)

    send(subscriber, :stop)
    assert_receive {:DOWN, _, _, ^node, _}
    assert :ets.lookup(Node, node) == []
  end

  test "deletes a reference from parent node after exit" do
    subscriber =
      spawn_link(fn ->
        receive do
          :stop -> :ok
        end
      end)

    {:ok, parent_node} = Node.start_link()
    %{code: code} = Filter.new(fn a -> a == "a" end)
    Node.put(parent_node, code, subscriber)
    node = :sys.get_state(parent_node).operations[{:access, []}]["a"]
    Process.monitor(node)

    send(subscriber, :stop)

    receive do
      {:DOWN, _, _, ^node, _} -> :ok
    end

    assert :sys.get_state(parent_node).operations == %{}
  end

  test "does not exit if root even when all subscribers have downed and operations is empty" do
    subscriber =
      spawn_link(fn ->
        receive do
          :stop -> :ok
        end
      end)

    {:ok, node} = Node.start_link()
    Process.monitor(node)
    %{code: code} = Filter.new(fn a -> a == "a" end)
    Node.put(node, code, subscriber)

    send(subscriber, :stop)
    refute_receive {:DOWN, _, _, ^node, _}
  end

  test "pushes an event without raise right after node stops" do
    subscriber =
      spawn_link(fn ->
        receive do
          :stop -> :ok
        end
      end)

    {:ok, node} = Node.start_link()

    %{code: code} = Filter.new(fn a -> a == "a" end)

    Node.put(node, code, subscriber)

    for _ <- 0..100 do
      spawn_link(fn ->
        for _ <- 0..100 do
          Node.push(node, "a")
        end
      end)
    end

    spawn_link(fn ->
      send(subscriber, :stop)
    end)

    :timer.sleep(100)
  end

  test "puts a subscription without raise right after node stops" do
    for _ <- 0..5 do
      subscriber =
        spawn_link(fn ->
          receive do
            :stop -> :ok
          end
        end)

      {:ok, node} = Node.start_link()

      %{code: code} = Filter.new(fn a -> a == "a" end)
      Node.put(node, code, subscriber)

      for _ <- 0..100 do
        spawn_link(fn ->
          for _ <- 0..100 do
            Node.put(node, code, subscriber)
          end
        end)
      end

      spawn_link(fn ->
        send(subscriber, :stop)
      end)

      :timer.sleep(100)
    end
  end
end
