defmodule Cizen.Dispatcher.IntakeTest do
  use ExUnit.Case

  import Mock

  alias Cizen.Dispatcher.{Intake, Sender, Node}
  alias Cizen.Event

  defmodule(TestEvent, do: defstruct([]))

  setup_with_mocks([
    {
      Sender,
      [:passthrough],
      [
        wait_node: fn _, _ -> :ok end,
        put_event: fn _, _ -> :ok end
      ]
    },
    {
      Node,
      [:passthrough],
      [
        push: fn _, _, _ -> :ok end
      ]
    }
  ]) do
    event = Event.new(nil, %TestEvent{})
    %{some_event: event}
  end

  test "starts sender with nil for first time of starting" do
    GenServer.start_link(Intake, :ok, name: TestIntake)

    :timer.sleep(10)
    assert_called(Sender.start_link(nil))
  end

  test "starts sender with preceding one for second or later", %{some_event: event} do
    Intake.start_link()
    %{sender: preceding} = :sys.get_state(Intake)
    Intake.push(event)

    :timer.sleep(10)
    assert_called(Sender.start_link(preceding))
  end

  test "pushes an event to root node", %{some_event: event} do
    Intake.start_link()
    %{sender: sender} = :sys.get_state(Intake)
    Intake.push(event)

    :timer.sleep(10)
    assert_called(Node.push(sender, event))
  end

  test "sends root node and event to sender before pushing an event to root node", %{
    some_event: event
  } do
    Intake.start_link()
    %{sender: sender} = :sys.get_state(Intake)
    Intake.push(event)

    :timer.sleep(10)
    assert_called(Sender.put_event(sender, event))
    assert_called(Sender.wait_node(sender, Node))
    assert_called(Node.push(sender, event))
  end
end
