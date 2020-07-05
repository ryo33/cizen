defmodule Cizen.Dispatcher.IntakeTest do
  use ExUnit.Case

  alias Cizen.Dispatcher.{Intake, Node}
  alias Cizen.Event

  defmodule(TestEvent, do: defstruct([]))

  test "starts sender with event" do
    event = Event.new(nil, %TestEvent{})
    {:ok, intake} = GenServer.start_link(Intake, nil)
    Intake.push(intake, event)
    sender = :sys.get_state(intake)

    assert %{event: ^event} = :sys.get_state(sender)
  end

  test "pushes an event to root node" do
    event = Event.new(nil, %TestEvent{})
    {:ok, intake} = GenServer.start_link(Intake, nil)

    GenServer.whereis(Node)
    |> :erlang.trace(true, [:receive])

    Intake.push(intake, event)
    assert_receive {:trace, _, _, {:"$gen_cast", {:push, _, _, ^event}}}
  end
end
