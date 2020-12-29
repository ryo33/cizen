defmodule Cizen.Dispatcher.SenderTest do
  use ExUnit.Case

  alias Cizen.Dispatcher.Sender
  alias Cizen.Event

  defmodule(TestEvent, do: defstruct([]))

  setup do
    pid = self()
    event = Event.new(nil, %TestEvent{})

    subscriber1 =
      spawn(fn ->
        receive do
          ^event -> :ok
        end

        send(pid, :received_subscriber1)
      end)

    subscriber2 =
      spawn(fn ->
        receive do
          ^event -> :ok
        end

        send(pid, :received_subscriber2)
      end)

    %{some_event: event, subscriber1: subscriber1, subscriber2: subscriber2}
  end

  test "sender sends an event to root node", %{some_event: event} do
    root_node = spawn_link(fn -> loop() end)
    root_node |> :erlang.trace(true, [:receive])
    {:ok, sender} = Sender.start_link(name: :a, root_node: root_node, next_sender: self())

    refute_receive {:trace, ^root_node, :receive, {:"$gen_cast", {:push, ^root_node, :a, ^event}}}
    Sender.push(sender, event)
    assert_receive {:trace, ^root_node, :receive, {:"$gen_cast", {:push, ^root_node, :a, ^event}}}
  end

  test "sender sends event to subscribers", %{
    some_event: event,
    subscriber1: subscriber1,
    subscriber2: subscriber2
  } do
    root_node = spawn_link(fn -> loop() end)
    {:ok, sender} = Sender.start_link(name: :a, root_node: root_node, next_sender: self())
    leaf_node = spawn_link(fn -> loop() end)
    Sender.push(sender, event)
    Sender.allow_to_send(sender)

    Sender.put_subscribers_and_following_nodes(sender, root_node, [subscriber1], [leaf_node])
    refute_receive :received_subscriber1
    refute_receive :received_subscriber2
    Sender.put_subscribers_and_following_nodes(sender, leaf_node, [subscriber2], [])
    assert_receive :received_subscriber1
    assert_receive :received_subscriber2
  end

  test "sender does not send event to subscribers if not allowed to send", %{
    some_event: event,
    subscriber1: subscriber
  } do
    node = spawn_link(fn -> loop() end)
    {:ok, sender} = Sender.start_link(name: :a, root_node: node, next_sender: self())
    Sender.push(sender, event)

    Sender.put_subscribers_and_following_nodes(sender, node, [subscriber], [])
    refute_receive :received_subscriber1
    Sender.allow_to_send(sender)
    assert_receive :received_subscriber1
  end

  test "sender does not send event to subscribers if waiting one or more nodes", %{
    some_event: event,
    subscriber1: subscriber
  } do
    node = spawn_link(fn -> loop() end)
    node2 = spawn_link(fn -> loop() end)
    {:ok, sender} = Sender.start_link(name: :a, root_node: node, next_sender: self())
    Sender.push(sender, event)
    Sender.allow_to_send(sender)

    Sender.put_subscribers_and_following_nodes(sender, node, [], [node2])
    refute_receive :received_subscriber1
    Sender.put_subscribers_and_following_nodes(sender, node2, [subscriber], [])
    assert_receive :received_subscriber1
  end

  test "allow the next node to send an event after sent an event", %{some_event: event} do
    node = spawn_link(fn -> loop() end)
    {:ok, next} = Sender.start_link(name: :next, root_node: node, next_sender: self())
    next |> :erlang.trace(true, [:receive])
    {:ok, sender} = Sender.start_link(name: :a, root_node: node, next_sender: :next)
    Sender.push(sender, event)
    Sender.allow_to_send(sender)

    refute_receive {:trace, ^next, :receive, {:"$gen_cast", :allow_to_send}}
    Sender.put_subscribers_and_following_nodes(sender, node, [], [])
    assert_receive {:trace, ^next, :receive, {:"$gen_cast", :allow_to_send}}
  end

  defp loop do
    receive do
      _ -> loop()
    end
  end
end
