defmodule Cizen.EventFilterDispatcherTest do
  use Cizen.SagaCase

  alias Cizen.TestHelper
  import Cizen.TestHelper, only: [launch_test_saga: 0, launch_test_saga: 1, assert_condition: 2]

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.EventFilter
  alias Cizen.EventFilterDispatcher
  alias Cizen.EventFilterDispatcher.PushEvent
  alias Cizen.SagaID

  defmodule(TestEvent, do: defstruct([:value]))

  test "subscribe/3 sets the meta data" do
    saga_id = launch_test_saga()
    subscription = EventFilterDispatcher.subscribe(saga_id, nil, %EventFilter{}, :value)
    assert subscription.meta == :value
  end

  test "subscribe/2 event" do
    pid = self()
    saga_id = launch_test_saga(handle_event: fn _id, event, _state -> send(pid, event) end)
    source_saga_id = SagaID.new()

    event_filter = %EventFilter{
      source_saga_id: source_saga_id
    }

    EventFilterDispatcher.subscribe(saga_id, nil, event_filter)

    Dispatcher.dispatch(Event.new(source_saga_id, %TestEvent{value: :a}))
    Dispatcher.dispatch(Event.new(SagaID.new(), %TestEvent{value: :b}))

    assert_receive %Event{
      body: %PushEvent{
        event: %Event{body: %TestEvent{value: :a}},
        subscriptions: [subscription]
      }
    }

    refute_receive %Event{body: %TestEvent{value: :b}}
  end

  test "dispatches EventFilterDispatcher.Subscribe.Subscribed event" do
    saga_id = launch_test_saga()
    Dispatcher.listen_event_type(EventFilterDispatcher.Subscribe.Subscribed)
    subscription = EventFilterDispatcher.subscribe(saga_id, nil, %EventFilter{}, :value)

    assert_receive %Event{
      body: %EventFilterDispatcher.Subscribe.Subscribed{subscription: ^subscription}
    }
  end

  test "dispatches for subscriber" do
    pid = self()
    saga_a = launch_test_saga(handle_event: fn _id, event, _state -> send(pid, {:a, event}) end)
    saga_b = launch_test_saga(handle_event: fn _id, event, _state -> send(pid, {:b, event}) end)
    source_saga_id = SagaID.new()

    EventFilterDispatcher.subscribe(saga_a, nil, %EventFilter{
      source_saga_id: source_saga_id
    })

    EventFilterDispatcher.subscribe(saga_b, nil, %EventFilter{
      source_saga_id: SagaID.new()
    })

    Dispatcher.dispatch(Event.new(source_saga_id, %TestEvent{value: :a}))

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
    pid = self()
    saga_id = launch_test_saga(handle_event: fn _id, event, _state -> send(pid, event) end)
    source_saga_id = SagaID.new()

    subscription_a =
      EventFilterDispatcher.subscribe(
        saga_id,
        nil,
        %EventFilter{
          source_saga_id: source_saga_id
        },
        :a
      )

    subscription_b =
      EventFilterDispatcher.subscribe(
        saga_id,
        nil,
        %EventFilter{
          source_saga_id: source_saga_id
        },
        :b
      )

    Dispatcher.dispatch(Event.new(source_saga_id, %TestEvent{value: :a}))

    received =
      assert_receive %Event{
        body: %PushEvent{
          event: %Event{body: %TestEvent{value: :a}}
        }
      }

    assert MapSet.new(received.body.subscriptions) ==
             MapSet.new([
               subscription_a,
               subscription_b
             ])
  end

  test "uses proxy saga" do
    pid = self()
    proxy_saga_id = launch_test_saga(handle_event: fn _id, event, _state -> send(pid, event) end)
    saga_id = launch_test_saga()
    source_saga_id = SagaID.new()

    EventFilterDispatcher.subscribe_as_proxy(
      proxy_saga_id,
      saga_id,
      nil,
      %EventFilter{
        source_saga_id: source_saga_id
      }
    )

    Dispatcher.dispatch(Event.new(source_saga_id, %TestEvent{value: :a}))

    assert_receive %Event{
      body: %PushEvent{
        event: %Event{body: %TestEvent{value: :a}}
      }
    }
  end

  test "ignores PushEvent event" do
    pid = self()
    saga_id = launch_test_saga(handle_event: fn _id, event, _state -> send(pid, event) end)
    source_saga_id = SagaID.new()

    EventFilterDispatcher.subscribe(saga_id, nil, %EventFilter{
      source_saga_id: source_saga_id
    })

    Dispatcher.dispatch(
      Event.new(
        source_saga_id,
        %PushEvent{
          saga_id: launch_test_saga(),
          event: Event.new(nil, %TestEvent{}),
          subscriptions: []
        }
      )
    )

    refute_receive %Event{}
  end

  test "remove the subscription when the saga finishes" do
    saga_id = launch_test_saga()
    source_saga_id = SagaID.new()

    old_state = :sys.get_state(EventFilterDispatcher)

    Dispatcher.listen_event_type(PushEvent)

    EventFilterDispatcher.subscribe(saga_id, nil, %EventFilter{
      event_type: TestEvent,
      source_saga_id: source_saga_id
    })

    TestHelper.ensure_finished(saga_id)

    assert_condition(100, :sys.get_state(EventFilterDispatcher) == old_state)

    Dispatcher.dispatch(Event.new(source_saga_id, %TestEvent{value: :a}))

    refute_receive %Event{body: %PushEvent{event: %Event{body: %TestEvent{}}}}
  end
end
