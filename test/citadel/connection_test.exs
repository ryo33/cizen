defmodule Citadel.ConnectionTest do
  use ExUnit.Case
  alias Citadel.TestHelper

  alias Citadel.Channel
  alias Citadel.Channel.EmitMessage
  alias Citadel.Channel.FeedMessage
  alias Citadel.Channel.RejectMessage
  alias Citadel.Connection
  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.Message
  alias Citadel.ReceiveMessage
  alias Citadel.Saga
  alias Citadel.SagaID
  alias Citadel.SagaLauncher

  defmodule(TestEvent, do: defstruct([:value]))

  setup do
    saga_id = SagaID.new()
    Dispatcher.listen_event_type(FeedMessage)
    Dispatcher.listen_event_type(EmitMessage)
    Dispatcher.listen_event_type(ReceiveMessage)
    Dispatcher.listen_event_body(%Saga.Finished{id: saga_id})

    message = %Message{
      event: Event.new(%TestEvent{}),
      subscriber_saga_id: SagaID.new(),
      subscriber_saga_module: TestSaga
    }

    # Sender -> A -> C -> Receiver
    #             -> D ->
    #        -> B

    channel_a = %Channel{
      saga_id: SagaID.new(),
      saga_module: ChannelA
    }

    channel_b = %Channel{
      saga_id: SagaID.new(),
      saga_module: ChannelB
    }

    channel_c = %Channel{
      saga_id: SagaID.new(),
      saga_module: ChannelC,
      previous_channel_module: channel_a.saga_module
    }

    channel_d = %Channel{
      saga_id: SagaID.new(),
      saga_module: ChannelD,
      previous_channel_module: channel_a.saga_module
    }

    channels = [channel_a, channel_b, channel_c, channel_d]

    Dispatcher.dispatch(
      Event.new(%SagaLauncher.LaunchSaga{
        id: saga_id,
        module: Connection,
        state: {message, channels}
      })
    )

    on_exit(fn ->
      TestHelper.ensure_finished(saga_id)
    end)

    [
      connection_id: saga_id,
      message: message,
      channels: %{
        a: channel_a,
        b: channel_b,
        c: channel_c,
        d: channel_d
      }
    ]
  end

  test "dispatches FeedMessage on launch", %{
    connection_id: connection_id,
    message: message,
    channels: channels
  } do
    # Sender -> A    C    Receiver
    #                D
    #        -> B

    %{a: channel_a, b: channel_b} = channels

    assert_receive %Event{
      body: %FeedMessage{
        connection_id: ^connection_id,
        channel: ^channel_a,
        message: ^message
      }
    }

    assert_receive %Event{
      body: %FeedMessage{
        connection_id: ^connection_id,
        channel: ^channel_b,
        message: ^message
      }
    }

    refute_receive %Event{}
  end

  test "dispatches FeedMessage to next channels",
       %{
         connection_id: connection_id,
         message: message,
         channels: channels
       } = context do
    # Sender    A -> C    Receiver
    #             -> D
    #           B

    %{a: channel_a, c: channel_c, d: channel_d} = channels

    flush(context)

    event =
      Event.new(%EmitMessage{
        connection_id: connection_id,
        channel: channel_a,
        message: message
      })

    Dispatcher.dispatch(event)
    assert_receive ^event

    assert_receive %Event{
      body: %FeedMessage{
        connection_id: ^connection_id,
        channel: ^channel_c,
        message: ^message
      }
    }

    assert_receive %Event{
      body: %FeedMessage{
        connection_id: ^connection_id,
        channel: ^channel_d,
        message: ^message
      }
    }

    refute_receive %Event{}
  end

  test "dispatches ReceiveMessage when a end channel emits the message",
       %{
         connection_id: connection_id,
         message: message,
         channels: channels
       } = context do
    # Sender    A    C -> Receiver
    #                D
    #           B

    %{c: channel_c} = channels

    flush(context)

    event =
      Event.new(%EmitMessage{
        connection_id: connection_id,
        channel: channel_c,
        message: message
      })

    Dispatcher.dispatch(event)
    assert_receive ^event

    assert_receive %Event{
      body: %ReceiveMessage{
        message: ^message
      }
    }

    assert_receive %Event{body: %Saga.Finished{id: connection_id}}

    refute_receive %Event{}
  end

  test "dispatches ReceiveMessage once even if multiple end channel emit message",
       %{
         connection_id: connection_id,
         message: message,
         channels: channels
       } = context do
    # Sender    A    C -> Receiver
    #                D ->
    #           B

    %{c: channel_c, d: channel_d} = channels

    flush(context)

    event =
      Event.new(%EmitMessage{
        connection_id: connection_id,
        channel: channel_c,
        message: message
      })

    Dispatcher.dispatch(event)
    assert_receive ^event

    event =
      Event.new(%EmitMessage{
        connection_id: connection_id,
        channel: channel_d,
        message: message
      })

    Dispatcher.dispatch(event)
    assert_receive ^event

    assert_receive %Event{
      body: %ReceiveMessage{
        message: ^message
      }
    }

    assert_receive %Event{body: %Saga.Finished{id: connection_id}}

    refute_receive %Event{}
  end

  test "finishes after dispatching ReceiveMessage",
       %{
         connection_id: connection_id,
         message: message,
         channels: channels
       } = context do
    %{c: channel_c} = channels

    flush(context)

    event =
      Event.new(%EmitMessage{
        connection_id: connection_id,
        channel: channel_c,
        message: message
      })

    Dispatcher.dispatch(event)
    assert_receive ^event

    assert_receive %Event{body: %ReceiveMessage{message: ^message}}

    assert_receive %Event{
      body: %Saga.Finished{
        id: connection_id
      }
    }

    refute_receive %Event{}
  end

  test "finishes when all active channel rejects the message",
       %{
         connection_id: connection_id,
         message: message,
         channels: channels
       } = context do
    # Sender    A -> C x  Receiver
    #                D x
    #           B x

    %{a: channel_a, b: channel_b, c: channel_c, d: channel_d} = channels

    flush(context)

    event =
      Event.new(%EmitMessage{
        connection_id: connection_id,
        channel: channel_a,
        message: message
      })

    Dispatcher.dispatch(event)
    assert_receive ^event
    assert_receive %Event{body: %FeedMessage{channel: ^channel_c}}
    assert_receive %Event{body: %FeedMessage{channel: ^channel_d}}

    Dispatcher.dispatch(
      Event.new(%RejectMessage{
        connection_id: connection_id,
        channel: channel_b,
        message: message
      })
    )

    Dispatcher.dispatch(
      Event.new(%RejectMessage{
        connection_id: connection_id,
        channel: channel_c,
        message: message
      })
    )

    Dispatcher.dispatch(
      Event.new(%RejectMessage{
        connection_id: connection_id,
        channel: channel_d,
        message: message
      })
    )

    assert_receive %Event{
      body: %Saga.Finished{
        id: connection_id
      }
    }

    refute_receive %Event{}
  end

  test "should not finish when one or more channel is active",
       %{
         connection_id: connection_id,
         message: message,
         channels: channels
       } = context do
    # Sender    A -> C x  Receiver
    #                D
    #           B x

    %{a: channel_a, b: channel_b, c: channel_c, d: channel_d} = channels

    flush(context)

    event =
      Event.new(%EmitMessage{
        connection_id: connection_id,
        channel: channel_a,
        message: message
      })

    Dispatcher.dispatch(event)
    assert_receive ^event
    assert_receive %Event{body: %FeedMessage{channel: ^channel_c}}
    assert_receive %Event{body: %FeedMessage{channel: ^channel_d}}

    Dispatcher.dispatch(
      Event.new(%RejectMessage{
        connection_id: connection_id,
        channel: channel_b,
        message: message
      })
    )

    Dispatcher.dispatch(
      Event.new(%RejectMessage{
        connection_id: connection_id,
        channel: channel_c,
        message: message
      })
    )

    refute_receive %Event{
      body: %Saga.Finished{
        id: ^connection_id
      }
    }

    refute_receive %Event{}
  end

  defp flush(%{
         connection_id: connection_id,
         message: message,
         channels: channels
       }) do
    %{a: channel_a, b: channel_b} = channels

    receive do
      %Event{
        body: %FeedMessage{
          connection_id: ^connection_id,
          channel: ^channel_a,
          message: ^message
        }
      } ->
        :ok
    after
      100 -> :ok
    end

    receive do
      %Event{
        body: %FeedMessage{
          connection_id: ^connection_id,
          channel: ^channel_b,
          message: ^message
        }
      } ->
        :ok
    after
      100 -> :ok
    end
  end
end
