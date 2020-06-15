defmodule Cizen.Dispatcher.NodeTest do
  use ExUnit.Case

  import Mock

  alias Cizen.Dispatcher.{Node, Sender}
  alias Cizen.Filter

  require Filter

  defmodule(TestEvent, do: defstruct([]))

  setup_with_mocks([
    {
      Sender,
      [:passthrough],
      [
        init: fn _ -> {:ok, nil} end,
        put_subscribers_and_following_nodes: fn _, _, _, _ -> :ok end
      ]
    },
    {Node, [:passthrough], []}
  ]) do
    :ok
  end

  describe "push" do
    test "pushes an event to following nodes" do
      subscriber = self()
      {:ok, sender} = Sender.start_link(nil)
      {:ok, node} = Node.start_link()

      %{code: code} = Filter.new(fn a -> a == "a" or a == "b" end)
      event = "a"
      Node.put(node, code, subscriber)
      Node.push(node, sender, event)

      :timer.sleep(10)

      following_node =
        :sys.get_state(node)
        |> get_in([:operations, {:access, []}, "a"])

      assert_called(Node.push(following_node, sender, event))
    end

    test "sends subscribers and following nodes to sender before pushing an event to following nodes" do
      subscriber = self()
      {:ok, sender} = Sender.start_link(nil)
      {:ok, node} = Node.start_link()

      %{code: code} = Filter.new(fn a -> a == "a" or a == "b" end)
      event = "a"
      Node.put(node, code, subscriber)
      Node.push(node, sender, event)

      :timer.sleep(10)

      following_node =
        :sys.get_state(node)
        |> get_in([:operations, {:access, []}, "a"])

      assert_called(
        Sender.put_subscribers_and_following_nodes(sender, node, [], [following_node])
      )

      assert_called(
        Sender.put_subscribers_and_following_nodes(sender, following_node, [subscriber], [])
      )
    end
  end

  describe "put" do
    test "put true" do
      subscriber = self()
      {:ok, node} = Node.start_link()
      Node.put(node, true, subscriber)

      actual = :sys.get_state(node)

      expected = %{
        operations: %{},
        subscribers: MapSet.new([subscriber])
      }

      assert expected == actual
    end

    test "put operation" do
      subscriber = self()
      {:ok, node} = Node.start_link()

      with_mock Node, [:passthrough], [] do
        Node.put(node, {:<>, ["a", "b"]}, subscriber)

        :timer.sleep(10)
        assert_called(Node.handle_cast({:run, {:put_subscriber, subscriber}}, :_))
      end
    end

    test "put :==" do
      subscriber = self()
      {:ok, node} = Node.start_link()

      with_mock Node, [:passthrough], [] do
        Node.put(node, {:==, [{:access, [:key]}, "a"]}, subscriber)

        :timer.sleep(10)
        assert_called(Node.handle_cast({:run, {:put_subscriber, subscriber}}, :_))
      end
    end

    test "put not" do
      subscriber = self()
      {:ok, node} = Node.start_link()

      with_mock Node, [:passthrough], [] do
        Node.put(node, {:not, [{:access, [:key]}]}, subscriber)

        :timer.sleep(10)
        assert_called(Node.handle_cast({:run, {:put_subscriber, subscriber}}, :_))
      end
    end

    test "put and" do
      subscriber = self()
      {:ok, node} = Node.start_link()

      with_mock Node, [:passthrough], [] do
        Node.put(node, {:and, ["a", {:and, ["b", "c"]}]}, subscriber)

        :timer.sleep(10)
        assert_called(Node.handle_cast({:run, {:put_subscriber, subscriber}}, :_))
      end
    end

    test "put or" do
      subscriber = self()
      {:ok, node} = Node.start_link()

      with_mock Node, [:passthrough], [] do
        Node.put(node, {:or, ["a", {:or, ["b", "c"]}]}, subscriber)

        :timer.sleep(10)
        assert_called(Node.handle_cast({:run, {:put_subscriber, subscriber}}, :_))
      end
    end
  end

  describe "delete" do
    # 1
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

      assert expected == actual
    end

    # x -> x + 1 (mock)
    test "delete operation" do
      subscriber = self()
      {:ok, node} = Node.start_link()

      with_mock Node, [:passthrough], [] do
        Node.put(node, {:<>, ["a", "b"]}, subscriber)
        Node.delete(node, {:<>, ["a", "b"]}, subscriber)

        :timer.sleep(10)
        assert_called(Node.handle_cast({:run, {:delete_subscriber, subscriber}}, :_))
      end
    end
  end

  test "delete the subscriber from subscribers when it downed" do
    subscriber =
      spawn(fn ->
        receive do
          :stop -> :ok
        end
      end)

    {:ok, node} = Node.start_link()
    set = MapSet.new([subscriber])
    empty = MapSet.new()

    Node.put(node, true, subscriber)
    assert %{subscribers: ^set} = Node.expand(node)
    send(subscriber, :stop)
    assert %{subscribers: ^empty} = Node.expand(node)
  end
end
