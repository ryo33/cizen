defmodule Citadel.EventFilterDispatcherTest do
  use ExUnit.Case

  import Citadel.TestHelper, only: [launch_test_saga: 0, launch_test_saga: 1]

  alias Citadel.Event
  alias Citadel.EventFilter
  alias Citadel.EventFilterDispatcher
  alias Citadel.EventFilterDispatcher.PushEvent
  alias Citadel.SagaID
  import Citadel.Dispatcher, only: [dispatch: 1]

  defmodule(TestEvent, do: defstruct([:value]))

  test "subscribe/3 sets the meta data" do
    saga_id = launch_test_saga()
    subscription = EventFilterDispatcher.subscribe(saga_id, %EventFilter{}, :value)
    assert subscription.meta == :value
  end

  test "subscribe/2 event" do
    pid = self()
    saga_id = launch_test_saga(handle_event: fn _id, event, _state -> send(pid, event) end)
    source_saga_id = SagaID.new()

    event_filter = %EventFilter{
      source_saga_id: source_saga_id
    }

    EventFilterDispatcher.subscribe(saga_id, event_filter)

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
    pid = self()
    saga_a = launch_test_saga(handle_event: fn _id, event, _state -> send(pid, {:a, event}) end)
    saga_b = launch_test_saga(handle_event: fn _id, event, _state -> send(pid, {:b, event}) end)
    source_saga_id = SagaID.new()

    EventFilterDispatcher.subscribe(saga_a, %EventFilter{
      source_saga_id: source_saga_id
    })

    EventFilterDispatcher.subscribe(saga_b, %EventFilter{
      source_saga_id: SagaID.new()
    })

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
    pid = self()
    saga_id = launch_test_saga(handle_event: fn _id, event, _state -> send(pid, event) end)
    source_saga_id = SagaID.new()

    subscription_a =
      EventFilterDispatcher.subscribe(
        saga_id,
        %EventFilter{
          source_saga_id: source_saga_id
        },
        :a
      )

    subscription_b =
      EventFilterDispatcher.subscribe(
        saga_id,
        %EventFilter{
          source_saga_id: source_saga_id
        },
        :b
      )

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
