defmodule Cizen.DispatcherTest do
  use ExUnit.Case

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.Filter
  require Cizen.Filter

  defmodule(TestEvent, do: defstruct([:value]))

  defp wait_until_receive(message) do
    receive do
      ^message -> :ok
    after
      100 -> flunk("#{message} timeout")
    end
  end

  @tag :skip
  test "listen_all" do
    pid = self()

    task1 =
      Task.async(fn ->
        Dispatcher.listen_all()
        send(pid, :task1)
        assert_receive %Event{body: %TestEvent{value: :a}}
        assert_receive %Event{body: %TestEvent{value: :b}}
      end)

    task2 =
      Task.async(fn ->
        Dispatcher.listen_all()
        send(pid, :task2)
        assert_receive %Event{body: %TestEvent{value: :a}}
        assert_receive %Event{body: %TestEvent{value: :b}}
      end)

    wait_until_receive(:task1)
    wait_until_receive(:task2)
    Dispatcher.dispatch(Event.new(nil, %TestEvent{value: :a}))
    Dispatcher.dispatch(Event.new(nil, %TestEvent{value: :b}))
    Task.await(task1)
    Task.await(task2)
  end

  defmodule(TestEventA, do: defstruct([:value]))
  defmodule(TestEventB, do: defstruct([:value]))

  test "listen_event_type" do
    pid = self()

    task1 =
      Task.async(fn ->
        Dispatcher.listen_event_type(TestEventA)
        send(pid, :task1)
        assert_receive %Event{body: %TestEventA{value: :a}}
        refute_receive %Event{body: %TestEventB{value: :b}}
      end)

    task2 =
      Task.async(fn ->
        Dispatcher.listen_event_type(TestEventA)
        Dispatcher.listen_event_type(TestEventB)
        send(pid, :task2)
        assert_receive %Event{body: %TestEventA{value: :a}}
        assert_receive %Event{body: %TestEventB{value: :b}}
      end)

    wait_until_receive(:task1)
    wait_until_receive(:task2)
    Dispatcher.dispatch(Event.new(nil, %TestEventA{value: :a}))
    Dispatcher.dispatch(Event.new(nil, %TestEventB{value: :b}))
    Task.await(task1)
    Task.await(task2)
  end

  @tag :skip
  test "listen_event_body" do
    pid = self()

    task1 =
      Task.async(fn ->
        Dispatcher.listen_event_body(%TestEvent{value: :a})
        send(pid, :task1)
        assert_receive %Event{body: %TestEvent{value: :a}}
        refute_receive %Event{body: %TestEvent{value: :b}}
      end)

    task2 =
      Task.async(fn ->
        Dispatcher.listen_event_body(%TestEvent{value: :a})
        Dispatcher.listen_event_body(%TestEvent{value: :b})
        send(pid, :task2)
        assert_receive %Event{body: %TestEvent{value: :a}}
        assert_receive %Event{body: %TestEvent{value: :b}}
      end)

    wait_until_receive(:task1)
    wait_until_receive(:task2)
    Dispatcher.dispatch(Event.new(nil, %TestEvent{value: :a}))
    Dispatcher.dispatch(Event.new(nil, %TestEvent{value: :b}))
    Task.await(task1)
    Task.await(task2)
  end

  test "listen" do
    pid = self()

    task1 =
      Task.async(fn ->
        Dispatcher.listen(Filter.new(fn %Event{body: %TestEventA{}} -> true end))
        send(pid, :task1)
        assert_receive %Event{body: %TestEventA{}}
        refute_receive %Event{body: %TestEventB{}}
      end)

    task2 =
      Task.async(fn ->
        Dispatcher.listen(Filter.new(fn %Event{body: %TestEventA{}} -> true end))
        Dispatcher.listen(Filter.new(fn %Event{body: %TestEventB{}} -> true end))
        send(pid, :task2)
        assert_receive %Event{body: %TestEventA{}}
        assert_receive %Event{body: %TestEventB{}}
      end)

    wait_until_receive(:task1)
    wait_until_receive(:task2)
    Dispatcher.dispatch(Event.new(nil, %TestEventA{}))
    Dispatcher.dispatch(Event.new(nil, %TestEventB{}))
    Task.await(task1)
    Task.await(task2)
  end
end
