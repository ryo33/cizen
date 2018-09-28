defmodule Citadel.SubscriptiveDispatcherTest do
  use ExUnit.Case

  import Citadel.TestHelper, only: [launch_test_saga: 1]

  alias Citadel.Event
  alias Citadel.SagaID
  alias Citadel.Subscribe
  alias Citadel.Subscribed
  alias Citadel.Subscription
  import Citadel.Dispatcher, only: [dispatch: 1, listen_event_type: 1]

  defmodule(TestEvent, do: defstruct([:value]))

  test "Subscribe event" do
    listen_event_type(Subscribed)
    pid = self()
    saga_id = launch_test_saga(handle_event: fn _id, event, _state -> send(pid, event) end)
    source_saga_id = SagaID.new()

    dispatch(
      Event.new(%Subscribe{
        subscription: %Subscription{
          subscriber_saga_id: saga_id,
          source_saga_id: source_saga_id
        }
      })
    )

    receive do
      %Event{body: %Subscribed{}} -> :ok
    after
      1000 -> :ok
    end

    dispatch(Event.new(%TestEvent{value: :a}, source_saga_id))
    dispatch(Event.new(%TestEvent{value: :b}, SagaID.new()))
    assert_receive %Event{body: %TestEvent{value: :a}}
    refute_receive %Event{body: %TestEvent{value: :b}}
  end

  test "dispatches for subscriber" do
    listen_event_type(Subscribed)
    pid = self()
    saga_a = launch_test_saga(handle_event: fn _id, event, _state -> send(pid, {:a, event}) end)
    saga_b = launch_test_saga(handle_event: fn _id, event, _state -> send(pid, {:b, event}) end)
    source_saga_id = SagaID.new()

    dispatch(
      Event.new(%Subscribe{
        subscription: %Subscription{
          subscriber_saga_id: saga_a,
          source_saga_id: source_saga_id
        }
      })
    )

    dispatch(
      Event.new(%Subscribe{
        subscription: %Subscription{
          subscriber_saga_id: saga_b,
          source_saga_id: SagaID.new()
        }
      })
    )

    receive do
      %Event{body: %Subscribed{}} -> :ok
    after
      1000 -> :ok
    end

    receive do
      %Event{body: %Subscribed{}} -> :ok
    after
      1000 -> :ok
    end

    dispatch(Event.new(%TestEvent{value: :a}, source_saga_id))
    assert_receive {:a, %Event{body: %TestEvent{value: :a}}}
    refute_receive {:b, _}
  end
end
