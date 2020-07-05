defmodule Cizen.Dispatcher.IntakeTest do
  use ExUnit.Case

  alias Cizen.Dispatcher.{Intake, Node}
  alias Cizen.Event

  defmodule(TestEvent, do: defstruct([]))

  test "starts sender with event" do
    event = Event.new(nil, %TestEvent{})
    Intake.push(event)
    {:links, [sender]} = Process.info(self(), :links)

    assert %{event: ^event} = :sys.get_state(sender)
  end

  test "pushes an event to root node" do
    event = Event.new(nil, %TestEvent{})

    GenServer.whereis(Node)
    |> :erlang.trace(true, [:receive])

    Intake.push(event)
    assert_receive {:trace, _, _, {:"$gen_cast", {:push, _, _, ^event}}}
  end
end
