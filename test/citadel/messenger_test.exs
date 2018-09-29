defmodule Citadel.MenssengerTest do
  use ExUnit.Case
  import Citadel.TestHelper, only: [launch_test_saga: 0]

  alias Citadel.Channel
  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.EventFilter
  alias Citadel.EventFilterSubscription
  alias Citadel.Message
  alias Citadel.Messenger
  alias Citadel.RegisterChannel
  alias Citadel.SagaID
  alias Citadel.SendMessage
  alias Citadel.SubscribeEventFilter
  alias Citadel.SubscribeMessage

  defmodule(TestEvent, do: defstruct([:value]))

  test "create event filter subscription on SubscribeMessage event" do
    Dispatcher.listen_event_type(SubscribeEventFilter)

    subscriber_saga_id = launch_test_saga()

    event_filter = %EventFilter{
      source_saga_id: SagaID.new()
    }

    Dispatcher.dispatch(
      Event.new(%SubscribeMessage{
        subscriber_saga_id: subscriber_saga_id,
        subscriber_saga_module: TestSaga,
        event_filter: event_filter
      })
    )

    assert_receive %Event{
      body: %SubscribeEventFilter{
        subscription: %EventFilterSubscription{
          subscriber_saga_id: ^subscriber_saga_id,
          subscriber_saga_module: TestSaga,
          event_filter: ^event_filter,
          meta: {^subscriber_saga_id, TestSaga}
        }
      }
    }
  end

  test "create event filter subscription on RegisterChannel event" do
    Dispatcher.listen_event_type(SubscribeEventFilter)

    subscriber_saga_id = launch_test_saga()

    channel = %Channel{
      saga_id: subscriber_saga_id,
      saga_module: TestSaga
    }

    event_filter = %EventFilter{
      source_saga_id: SagaID.new()
    }

    Dispatcher.dispatch(
      Event.new(%RegisterChannel{
        channel: channel,
        event_filter: event_filter
      })
    )

    assert_receive %Event{
      body: %SubscribeEventFilter{
        subscription: %EventFilterSubscription{
          subscriber_saga_id: ^subscriber_saga_id,
          subscriber_saga_module: TestSaga,
          event_filter: ^event_filter,
          meta: ^channel
        }
      }
    }
  end

  test "dispatches SendMessage event" do
    Dispatcher.listen_event_type(SendMessage)

    source_saga_id = SagaID.new()

    event_filter = %EventFilter{source_saga_id: source_saga_id}
    another_event_filter = %EventFilter{source_saga_id: SagaID.new()}

    subscriber_saga_a = launch_test_saga()
    subscriber_saga_b = launch_test_saga()
    subscriber_saga_c = launch_test_saga()

    channel_a = %Channel{saga_id: launch_test_saga(), saga_module: ChannelA}
    channel_b = %Channel{saga_id: launch_test_saga(), saga_module: ChannelB}
    channel_c = %Channel{saga_id: launch_test_saga(), saga_module: ChannelC}

    Messenger.subscribe_message(subscriber_saga_a, TestSagaA, event_filter)
    Messenger.subscribe_message(subscriber_saga_b, TestSagaB, event_filter)
    Messenger.subscribe_message(subscriber_saga_c, TestSagaC, another_event_filter)
    Messenger.register_channel(channel_a, event_filter)
    Messenger.register_channel(channel_b, event_filter)
    Messenger.register_channel(channel_c, another_event_filter)

    event = Event.new(%TestEvent{}, source_saga_id)
    Dispatcher.dispatch(event)

    received_a =
      assert_receive %Event{
        body: %SendMessage{
          message: %Message{
            event: ^event,
            destination_saga_id: ^subscriber_saga_a,
            destination_saga_module: TestSagaA
          }
        }
      }

    assert MapSet.new([channel_a, channel_b]) == MapSet.new(received_a.body.channels)

    received_b =
      assert_receive %Event{
        body: %SendMessage{
          message: %Message{
            event: ^event,
            destination_saga_id: ^subscriber_saga_b,
            destination_saga_module: TestSagaB
          }
        }
      }

    assert MapSet.new([channel_a, channel_b]) == MapSet.new(received_b.body.channels)
  end

  test "filters channels with using Channel.match?/2" do
    Dispatcher.listen_event_type(SendMessage)

    source_saga_id = SagaID.new()

    event_filter = %EventFilter{source_saga_id: source_saga_id}

    subscriber_saga_id = launch_test_saga()

    channel_a = %Channel{
      saga_id: launch_test_saga(),
      saga_module: ChannelA,
      destination_saga_id: subscriber_saga_id
    }

    channel_b = %Channel{
      saga_id: launch_test_saga(),
      saga_module: ChannelB,
      destination_saga_id: SagaID.new()
    }

    Messenger.subscribe_message(subscriber_saga_id, TestSaga, event_filter)
    Messenger.register_channel(channel_a, event_filter)
    Messenger.register_channel(channel_b, event_filter)

    event = Event.new(%TestEvent{}, source_saga_id)
    Dispatcher.dispatch(event)

    received =
      assert_receive %Event{
        body: %SendMessage{
          message: %Message{
            event: ^event,
            destination_saga_id: ^subscriber_saga_id,
            destination_saga_module: TestSaga
          }
        }
      }

    assert MapSet.new([channel_a]) == MapSet.new(received.body.channels)
  end
end
