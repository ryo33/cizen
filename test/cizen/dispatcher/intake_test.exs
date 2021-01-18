defmodule Cizen.Dispatcher.IntakeTest do
  use ExUnit.Case

  alias Cizen.Dispatcher.Intake
  alias Cizen.Event

  defmodule(TestEvent, do: defstruct([]))

  test "pushes an event to sender" do
    event = Event.new(nil, %TestEvent{})

    [{_, index}] = :ets.lookup(Intake, :index)
    [{_, sender_count}] = :ets.lookup(Intake, :sender_count)

    sender = GenServer.whereis(:"#{Cizen.Dispatcher.Sender}_#{rem(index + 1, sender_count)}")

    :erlang.trace(sender, true, [:receive])

    refute_receive {:trace, ^sender, :receive, {:"$gen_cast", {:push, ^event}}}
    Intake.push(event)
    assert_receive {:trace, ^sender, :receive, {:"$gen_cast", {:push, ^event}}}
  end

  test "increments index" do
    event = Event.new(nil, %TestEvent{})

    [{_, previous_index}] = :ets.lookup(Intake, :index)
    Intake.push(event)
    [{_, index}] = :ets.lookup(Intake, :index)
    assert index == previous_index + 1
  end
end
