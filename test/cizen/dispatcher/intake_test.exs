defmodule Cizen.Dispatcher.IntakeTest do
  use ExUnit.Case

  alias Cizen.Dispatcher.Intake
  alias Cizen.Event

  defmodule(TestEvent, do: defstruct([]))

  test "pushes an event to sender" do
    event = Event.new(nil, %TestEvent{})

    state = :sys.get_state(Intake)
    sender = GenServer.whereis(elem(state.senders, state.index))
    :erlang.trace(sender, true, [:receive])

    refute_receive {:trace, ^sender, :receive, {:"$gen_cast", {:push, ^event}}}
    Intake.push(event)
    assert_receive {:trace, ^sender, :receive, {:"$gen_cast", {:push, ^event}}}
  end

  test "increments index" do
    event = Event.new(nil, %TestEvent{})

    state = :sys.get_state(Intake)
    previous_index = state.index
    Intake.push(event)
    assert :sys.get_state(Intake).index == rem(previous_index + 1, tuple_size(state.senders))
  end
end
