defmodule Citadel.EventFilterDispatcherTest do
  use ExUnit.Case

  import Citadel.TestHelper, only: [launch_test_saga: 1]

  alias Citadel.Event
  alias Citadel.EventFilter
  alias Citadel.EventFilterDispatcher.PushEvent
  alias Citadel.EventFilterSubscribed
  alias Citadel.EventFilterSubscription
  alias Citadel.SagaID
  alias Citadel.SubscribeEventFilter
  import Citadel.Dispatcher, only: [dispatch: 1, listen_event_type: 1]

  defmodule(TestEvent, do: defstruct([:value]))

  test "SubscribeEventFilter event" do
    listen_event_type(EventFilterSubscribed)
    pid = self()
    saga_id = launch_test_saga(handle_event: fn _id, event, _state -> send(pid, event) end)
    source_saga_id = SagaID.new()

    subscription = %EventFilterSubscription{
      subscriber_saga_id: saga_id,
      event_filter: %EventFilter{
        source_saga_id: source_saga_id
      }
    }

    dispatch(
      Event.new(%SubscribeEventFilter{
        subscription: subscription
      })
    )

    receive do
      %Event{body: %EventFilterSubscribed{}} -> :ok
    after
      1000 -> :ok
    end

    dispatch(Event.new(%TestEvent{value: :a}, source_saga_id))
    dispatch(Event.new(%TestEvent{value: :b}, SagaID.new()))

    assert_receive %Event{
      body: %PushEvent{
        event: %Event{body: %TestEvent{value: :a}},
        subscriptions: [subscription]
      }
    }

    refute_receive %Event{body: %TestEvent{value: :b}}
  end

  test "dispatches for subscriber" do
    listen_event_type(EventFilterSubscribed)
    pid = self()
    saga_a = launch_test_saga(handle_event: fn _id, event, _state -> send(pid, {:a, event}) end)
    saga_b = launch_test_saga(handle_event: fn _id, event, _state -> send(pid, {:b, event}) end)
    source_saga_id = SagaID.new()

    subscription = %EventFilterSubscription{
      subscriber_saga_id: saga_a,
      event_filter: %EventFilter{
        source_saga_id: source_saga_id
      }
    }

    dispatch(Event.new(%SubscribeEventFilter{subscription: subscription}))

    dispatch(
      Event.new(%SubscribeEventFilter{
        subscription: %EventFilterSubscription{
          subscriber_saga_id: saga_b,
          event_filter: %EventFilter{
            source_saga_id: SagaID.new()
          }
        }
      })
    )

    receive do
      %Event{body: %EventFilterSubscribed{}} -> :ok
    after
      1000 -> :ok
    end

    receive do
      %Event{body: %EventFilterSubscribed{}} -> :ok
    after
      1000 -> :ok
    end

    dispatch(Event.new(%TestEvent{value: :a}, source_saga_id))

    assert_receive {:a,
                    %Event{
                      body: %PushEvent{
                        event: %Event{
                          body: %TestEvent{
                            value: :a
                          }
                        },
                        subscriptions: [subscription]
                      }
                    }}

    refute_receive {:b, _}
  end

  test "dispatches once for multiple subscriptions" do
    listen_event_type(EventFilterSubscribed)
    pid = self()
    saga_id = launch_test_saga(handle_event: fn _id, event, _state -> send(pid, event) end)
    source_saga_id = SagaID.new()

    subscription_a = %EventFilterSubscription{
      subscriber_saga_id: saga_id,
      event_filter: %EventFilter{
        source_saga_id: source_saga_id
      },
      meta: :a
    }

    subscription_b = %EventFilterSubscription{
      subscriber_saga_id: saga_id,
      event_filter: %EventFilter{
        source_saga_id: source_saga_id
      },
      meta: :b
    }

    dispatch(Event.new(%SubscribeEventFilter{subscription: subscription_a}))

    dispatch(Event.new(%SubscribeEventFilter{subscription: subscription_b}))

    receive do
      %Event{body: %EventFilterSubscribed{}} -> :ok
    after
      1000 -> :ok
    end

    receive do
      %Event{body: %EventFilterSubscribed{}} -> :ok
    after
      1000 -> :ok
    end

    dispatch(Event.new(%TestEvent{value: :a}, source_saga_id))

    receive do
      %Event{
        body: %PushEvent{
          event: %Event{body: %TestEvent{value: :a}},
          subscriptions: subscriptions
        }
      } ->
        assert MapSet.new(subscriptions) ==
                 MapSet.new([
                   subscription_a,
                   subscription_b
                 ])
    after
      100 -> flunk("timeout")
    end
  end
end
