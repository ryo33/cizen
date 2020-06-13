defmodule Cizen.Dispatcher.IntakeTest do
  use ExUnit.Case

  import Mock

  alias Cizen.Dispatcher.{Intake, Sender, RootNode, Node}
  alias Cizen.Event

  defmodule(TestEvent, do: defstruct([]))

  setup_with_mocks([
    {
      Sender,
      [:passthrough],
      [
        init: fn _ -> {:ok, nil} end,
        wait_node: fn _, _ -> :ok end,
        put_event: fn _, _ -> :ok end
      ]
    },
    {
      Node,
      [:passthrough],
      [
        init: fn _ -> {:ok, nil} end,
        push: fn _, _, _ -> :ok end
      ]
    }
  ]) do
    event = Event.new(nil, %TestEvent{})
    %{some_event: event}
  end

  test "starts sender with nil for first time of starting" do
    # Restart Intake here
    {:error, {:already_started, intake}} = Intake.start_link()
    GenServer.stop(intake)
    Intake.start_link()

    :timer.sleep(50)
    assert_called(Sender.start_link(nil))
  end

  test "starts sender with preceding one for second or later", %{some_event: event} do
    Intake.start_link()
    %{sender: preceding} = :sys.get_state(Intake)
    Intake.push(event)

    :timer.sleep(50)
    assert_called(Sender.start_link(preceding))
  end

  test "pushes an event to root node", %{some_event: event} do
    Intake.start_link()
    %{sender: sender} = :sys.get_state(Intake)
    Intake.push(event)

    :timer.sleep(50)
    assert_called(Node.push({:global, RootNode}, sender, event))
  end

  test "sends root node and event to sender before pushing an event to root node", %{
    some_event: event
  } do
    Intake.start_link()
    %{sender: sender} = :sys.get_state(Intake)
    Intake.push(event)

    :timer.sleep(50)
    assert_called(Sender.put_event(sender, event))
    assert_called(Sender.wait_node(sender, {:global, RootNode}))
    assert_called(Node.push({:global, RootNode}, sender, event))
  end
end
