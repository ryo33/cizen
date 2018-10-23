defmodule Cizen.MenssengerTest do
  use Cizen.SagaCase
  alias Cizen.TestHelper
  import Cizen.TestHelper, only: [launch_test_saga: 0, launch_test_saga: 1]

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.EventFilter
  alias Cizen.EventFilterDispatcher
  alias Cizen.Messenger
  alias Cizen.SagaID

  alias Cizen.Channel.EmitMessage
  alias Cizen.Channel.FeedMessage
  alias Cizen.RegisterChannel
  alias Cizen.SendMessage
  alias Cizen.SubscribeMessage

  defmodule(TestEvent, do: defstruct([:value]))

  test "create event filter subscription on SubscribeMessage event" do
    Dispatcher.listen_event_type(EventFilterDispatcher.Subscribe)

    subscriber_id = launch_test_saga()

    event_filter = %EventFilter{
      source_saga_id: SagaID.new()
    }

    Dispatcher.dispatch(
      Event.new(nil, %SubscribeMessage{
        subscriber_saga_id: subscriber_id,
        event_filter: event_filter
      })
    )

    assert_receive %Event{
      body: %EventFilterDispatcher.Subscribe{
        subscription: %EventFilterDispatcher.Subscription{
          subscriber_saga_id: ^subscriber_id,
          event_filter: ^event_filter,
          meta: {:subscriber, ^subscriber_id}
        }
      }
    }
  end

  test "create event filter subscription on RegisterChannel event" do
    Dispatcher.listen_event_type(EventFilterDispatcher.Subscribe)

    subscriber_id = launch_test_saga()

    event_filter = %EventFilter{
      source_saga_id: SagaID.new()
    }

    Dispatcher.dispatch(
      Event.new(nil, %RegisterChannel{
        channel_saga_id: subscriber_id,
        event_filter: event_filter
      })
    )

    assert_receive %Event{
      body: %EventFilterDispatcher.Subscribe{
        subscription: %EventFilterDispatcher.Subscription{
          subscriber_saga_id: ^subscriber_id,
          event_filter: ^event_filter,
          meta: :channel
        }
      }
    }
  end

  test "dispatches SendMessage event if no channels" do
    pid = self()

    source_id = launch_test_saga()

    event_filter = %EventFilter{source_saga_id: source_id}
    another_event_filter = %EventFilter{source_saga_id: SagaID.new()}

    subscriber_a = launch_test_saga(handle_event: fn id, event, _ -> send(pid, {id, event}) end)
    subscriber_b = launch_test_saga(handle_event: fn id, event, _ -> send(pid, {id, event}) end)
    subscriber_c = launch_test_saga(handle_event: fn id, event, _ -> send(pid, {id, event}) end)

    Messenger.subscribe_message(subscriber_a, event_filter)
    Messenger.subscribe_message(subscriber_b, event_filter)
    Messenger.subscribe_message(subscriber_c, another_event_filter)

    event = Event.new(source_id, %TestEvent{})
    Dispatcher.dispatch(event)

    assert_receive {^subscriber_a, ^event}

    assert_receive {^subscriber_b, ^event}

    refute_receive {^subscriber_c, ^event}
  end

  test "dispatches only FeedMessage event to channels" do
    pid = self()

    source_id = launch_test_saga()

    event_filter = %EventFilter{source_saga_id: source_id}
    another_event_filter = %EventFilter{source_saga_id: SagaID.new()}

    subscriber_a = launch_test_saga(handle_event: fn id, event, _ -> send(pid, {id, event}) end)
    subscriber_b = launch_test_saga(handle_event: fn id, event, _ -> send(pid, {id, event}) end)
    subscriber_c = launch_test_saga(handle_event: fn id, event, _ -> send(pid, {id, event}) end)

    Messenger.subscribe_message(subscriber_a, event_filter)
    Messenger.subscribe_message(subscriber_b, event_filter)
    Messenger.subscribe_message(subscriber_c, another_event_filter)

    channel_a = launch_test_saga(handle_event: fn id, event, _ -> send(pid, {id, event}) end)
    channel_b = launch_test_saga(handle_event: fn id, event, _ -> send(pid, {id, event}) end)
    channel_c = launch_test_saga(handle_event: fn id, event, _ -> send(pid, {id, event}) end)

    Messenger.register_channel(channel_a, event_filter)
    Messenger.register_channel(channel_b, event_filter)
    Messenger.register_channel(channel_c, another_event_filter)

    event = Event.new(source_id, %TestEvent{})
    Dispatcher.dispatch(event)

    {_, received} =
      assert_receive {^channel_a,
                      %Event{
                        body: %FeedMessage{
                          event: ^event,
                          channel_saga_id: ^channel_a
                        }
                      }}

    subscribers = received.body.subscribers
    assert length(subscribers)
    assert subscriber_a in subscribers
    assert subscriber_b in subscribers

    {_, received} =
      assert_receive {^channel_b,
                      %Event{
                        body: %FeedMessage{
                          event: ^event,
                          channel_saga_id: ^channel_b
                        }
                      }}

    subscribers = received.body.subscribers
    assert length(subscribers)
    assert subscriber_a in subscribers
    assert subscriber_b in subscribers

    refute_receive {^channel_c, %Event{body: %FeedMessage{}}}
    refute_receive {_, ^event}
  end

  test "dispatches event on EmitMessage when no channels are subscribing the emit event" do
    pid = self()

    source_id = launch_test_saga()

    subscriber_a = launch_test_saga(handle_event: fn id, event, _ -> send(pid, {id, event}) end)
    subscriber_b = launch_test_saga(handle_event: fn id, event, _ -> send(pid, {id, event}) end)
    subscribers = [subscriber_a, subscriber_b]

    channel = launch_test_saga()

    event = Event.new(source_id, %TestEvent{})
    emit_event = Event.new(channel, %EmitMessage{event: event, subscribers: subscribers})
    Dispatcher.dispatch(emit_event)

    assert_receive {^subscriber_a, ^event}

    assert_receive {^subscriber_b, ^event}
  end

  test "dispatches only FeedMessage on EmitMessage when some channels are subscribing the emit event" do
    pid = self()

    source_id = launch_test_saga()

    subscriber_a = launch_test_saga(handle_event: fn id, event, _ -> send(pid, {id, event}) end)
    subscriber_b = launch_test_saga(handle_event: fn id, event, _ -> send(pid, {id, event}) end)
    subscribers = [subscriber_a, subscriber_b]

    channel = launch_test_saga()

    event_filter = %EventFilter{
      event_type: EmitMessage,
      source_saga_id: channel
    }

    another_event_filter = %EventFilter{
      event_type: EmitMessage,
      source_saga_id: SagaID.new()
    }

    channel_a = launch_test_saga(handle_event: fn id, event, _ -> send(pid, {id, event}) end)
    channel_b = launch_test_saga(handle_event: fn id, event, _ -> send(pid, {id, event}) end)
    channel_c = launch_test_saga(handle_event: fn id, event, _ -> send(pid, {id, event}) end)

    Messenger.register_channel(channel_a, event_filter)
    Messenger.register_channel(channel_b, event_filter)
    Messenger.register_channel(channel_c, another_event_filter)

    event = Event.new(source_id, %TestEvent{})
    emit_event = Event.new(channel, %EmitMessage{event: event, subscribers: subscribers})
    Dispatcher.dispatch(emit_event)

    assert_receive {^channel_a,
                    %Event{
                      body: %FeedMessage{
                        event: ^emit_event,
                        channel_saga_id: ^channel_a
                      }
                    }}

    assert_receive {^channel_b,
                    %Event{
                      body: %FeedMessage{
                        event: ^emit_event,
                        channel_saga_id: ^channel_b
                      }
                    }}

    refute_receive {^channel_c, %Event{body: %FeedMessage{}}}

    refute_receive {_, ^event}
  end

  test "supports channel chaining" do
    pid = self()

    source_id = launch_test_saga()

    subscriber_a = launch_test_saga(handle_event: fn id, event, _ -> send(pid, {id, event}) end)
    subscriber_b = launch_test_saga(handle_event: fn id, event, _ -> send(pid, {id, event}) end)

    channel_a =
      launch_test_saga(
        handle_event: fn
          id, %Event{body: %FeedMessage{event: event, subscribers: subscribers}}, _ ->
            Dispatcher.dispatch(
              Event.new(id, %EmitMessage{
                event: event,
                subscribers: subscribers
              })
            )

          _, _, _ ->
            :ok
        end
      )

    channel_b =
      launch_test_saga(
        handle_event: fn
          id, %Event{body: %FeedMessage{event: event, subscribers: subscribers}}, _ ->
            Dispatcher.dispatch(
              Event.new(id, %EmitMessage{
                event: event,
                subscribers: subscribers
              })
            )

          _, _, _ ->
            :ok
        end
      )

    channel_c = launch_test_saga(handle_event: fn id, event, _ -> send(pid, {id, event}) end)

    Messenger.subscribe_message(subscriber_a, %EventFilter{
      event_type: TestEvent,
      source_saga_id: source_id
    })

    Messenger.subscribe_message(subscriber_b, %EventFilter{
      event_type: TestEvent,
      source_saga_id: source_id
    })

    Messenger.register_channel(channel_a, %EventFilter{
      event_type: TestEvent,
      source_saga_id: source_id
    })

    Messenger.register_channel(channel_b, %EventFilter{
      event_type: EmitMessage,
      source_saga_id: channel_a
    })

    Messenger.register_channel(channel_c, %EventFilter{
      event_type: EmitMessage,
      source_saga_id: channel_b
    })

    event = Event.new(source_id, %TestEvent{})
    Dispatcher.dispatch(event)

    {_, feed_event} =
      assert_receive {
        ^channel_c,
        %Event{
          body: %FeedMessage{
            event: %Event{
              body: %EmitMessage{
                event: %Event{
                  body: %EmitMessage{
                    event: ^event
                  }
                }
              }
            }
          }
        }
      }

    subscribers = feed_event.body.event.body.event.body.subscribers
    assert length(subscribers) == 2
    assert subscriber_a in subscribers
    assert subscriber_b in subscribers

    refute_receive {_, ^event}

    %Event{body: %FeedMessage{event: fed_event, subscribers: fed_subscribers}} = feed_event

    Dispatcher.dispatch(
      Event.new(channel_c, %EmitMessage{
        event: fed_event,
        subscribers: fed_subscribers
      })
    )

    assert_receive {^subscriber_a, ^event}
    assert_receive {^subscriber_b, ^event}
  end

  test "unsubscribe when the given lifetime saga finishes" do
    pid = self()
    Dispatcher.listen_event_type(SendMessage)

    subscriber = launch_test_saga(handle_event: fn id, event, _ -> send(pid, {id, event}) end)

    source_id = launch_test_saga()
    lifetime_saga = launch_test_saga()

    assert_handle(fn id ->
      perform id, %Request{
        body: %SubscribeMessage{
          subscriber_saga_id: subscriber,
          event_filter: %EventFilter{source_saga_id: source_id},
          lifetime_saga_id: lifetime_saga
        }
      }
    end)

    event = Event.new(source_id, %TestEvent{value: :a})
    Dispatcher.dispatch(event)

    assert_receive {^subscriber, ^event}

    TestHelper.ensure_finished(lifetime_saga)

    event = Event.new(source_id, %TestEvent{value: :b})
    Dispatcher.dispatch(event)

    refute_receive {^subscriber, ^event}
  end
end
