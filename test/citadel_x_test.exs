defmodule CitadelXTest do
  use ExUnit.Case
  doctest CitadelX
  import CitadelX.Dispatcher, only: [listen_all: 0, listen_event_type: 1, dispatch: 1]

  defmodule(TestEvent, do: defstruct([:value]))

  defp wait_until_receive(message) do
    receive do
      ^message -> :ok
    after
      100 -> flunk("#{message} timeout")
    end
  end

  test "listen_all" do
    pid = self()

    task1 =
      Task.async(fn ->
        listen_all()
        send(pid, :task1)
        assert_receive %TestEvent{value: :a}
        assert_receive %TestEvent{value: :b}
      end)

    task2 =
      Task.async(fn ->
        listen_all()
        send(pid, :task2)
        assert_receive %TestEvent{value: :a}
        assert_receive %TestEvent{value: :b}
      end)

    wait_until_receive(:task1)
    wait_until_receive(:task2)
    dispatch(%TestEvent{value: :a})
    dispatch(%TestEvent{value: :b})
    Task.await(task1)
    Task.await(task2)
  end

  defmodule(TestEventA, do: defstruct([:value]))
  defmodule(TestEventB, do: defstruct([:value]))

  test "listen_event_type" do
    pid = self()

    task1 =
      Task.async(fn ->
        listen_event_type(TestEventA)
        send(pid, :task1)
        assert_receive %TestEventA{value: :a}
        refute_receive %TestEventB{value: :b}
      end)

    task2 =
      Task.async(fn ->
        listen_event_type(TestEventA)
        listen_event_type(TestEventB)
        send(pid, :task2)
        assert_receive %TestEventA{value: :a}
        assert_receive %TestEventB{value: :b}
      end)

    wait_until_receive(:task1)
    wait_until_receive(:task2)
    dispatch(%TestEventA{value: :a})
    dispatch(%TestEventB{value: :b})
    Task.await(task1)
    Task.await(task2)
  end
end
