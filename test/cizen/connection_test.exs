defmodule Cizen.ConnectionTest do
  use Cizen.SagaCase
  import Cizen.TestHelper, only: [launch_test_saga: 0]

  alias Cizen.Channel
  alias Cizen.Channel.EmitMessage
  alias Cizen.Channel.FeedMessage
  alias Cizen.Channel.RejectMessage
  alias Cizen.Connection
  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.Message
  alias Cizen.ReceiveMessage
  alias Cizen.Saga
  alias Cizen.SagaID
  alias Cizen.SagaLauncher

  defmodule(TestEvent, do: defstruct([:value]))

  describe "Connection with no channels" do
    test "dispatches ReceiveMessage and finishes" do
      saga_id = SagaID.new()
      Dispatcher.listen_event_type(FeedMessage)
      Dispatcher.listen_event_type(EmitMessage)
      Dispatcher.listen_event_type(ReceiveMessage)
      Dispatcher.listen_event_body(%Saga.Finished{id: saga_id})

      message = %Message{
        event: Event.new(nil, %TestEvent{}),
        destination_saga_id: SagaID.new(),
        destination_saga_module: TestSaga
      }

      Dispatcher.dispatch(
        Event.new(nil, %SagaLauncher.LaunchSaga{
          id: saga_id,
          saga: %Connection{
            message: message,
            channels: []
          }
        })
      )

      assert_receive %Event{
        body: %ReceiveMessage{
          message: ^message
        }
      }

      assert_receive %Event{body: %Saga.Finished{id: connection_id}}

      refute_receive %Event{}
    end
  end

  defp setup_connection_with_channels(_context) do
    saga_id = SagaID.new()
    Dispatcher.listen_event_type(FeedMessage)
    Dispatcher.listen_event_type(EmitMessage)
    Dispatcher.listen_event_type(ReceiveMessage)
    Dispatcher.listen_event_body(%Saga.Finished{id: saga_id})

    message = %Message{
      event: Event.new(nil, %TestEvent{}),
      destination_saga_id: SagaID.new(),
      destination_saga_module: TestSaga
    }

    # Sender -> A -> C -> Receiver
    #             -> D ->
    #        -> B

    channel_a = %Channel{
      saga_id: launch_test_saga(),
      saga_module: ChannelA
    }

    channel_b = %Channel{
      saga_id: launch_test_saga(),
      saga_module: ChannelB
    }

    channel_c = %Channel{
      saga_id: launch_test_saga(),
      saga_module: ChannelC,
      previous_channel_module: channel_a.saga_module
    }

    channel_d = %Channel{
      saga_id: launch_test_saga(),
      saga_module: ChannelD,
      previous_channel_module: channel_a.saga_module
    }

    channels = [channel_a, channel_b, channel_c, channel_d]

    Dispatcher.dispatch(
      Event.new(nil, %SagaLauncher.LaunchSaga{
        id: saga_id,
        saga: %Connection{
          message: message,
          channels: channels
        }
      })
    )

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

  describe "Connection with channels" do
    setup [:setup_connection_with_channels]

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
        Event.new(nil, %EmitMessage{
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
        Event.new(nil, %EmitMessage{
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
        Event.new(nil, %EmitMessage{
          connection_id: connection_id,
          channel: channel_c,
          message: message
        })

      Dispatcher.dispatch(event)
      assert_receive ^event

      event =
        Event.new(nil, %EmitMessage{
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
        Event.new(nil, %EmitMessage{
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
        Event.new(nil, %EmitMessage{
          connection_id: connection_id,
          channel: channel_a,
          message: message
        })

      Dispatcher.dispatch(event)
      assert_receive ^event
      assert_receive %Event{body: %FeedMessage{channel: ^channel_c}}
      assert_receive %Event{body: %FeedMessage{channel: ^channel_d}}

      Dispatcher.dispatch(
        Event.new(nil, %RejectMessage{
          connection_id: connection_id,
          channel: channel_b,
          message: message
        })
      )

      Dispatcher.dispatch(
        Event.new(nil, %RejectMessage{
          connection_id: connection_id,
          channel: channel_c,
          message: message
        })
      )

      Dispatcher.dispatch(
        Event.new(nil, %RejectMessage{
          connection_id: connection_id,
          channel: channel_d,
          message: message
        })
      )

      assert_receive %Event{
        body: %Saga.Finished{
          id: ^connection_id
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
        Event.new(nil, %EmitMessage{
          connection_id: connection_id,
          channel: channel_a,
          message: message
        })

      Dispatcher.dispatch(event)
      assert_receive ^event
      assert_receive %Event{body: %FeedMessage{channel: ^channel_c}}
      assert_receive %Event{body: %FeedMessage{channel: ^channel_d}}

      Dispatcher.dispatch(
        Event.new(nil, %RejectMessage{
          connection_id: connection_id,
          channel: channel_b,
          message: message
        })
      )

      Dispatcher.dispatch(
        Event.new(nil, %RejectMessage{
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

    test "finishes when one or more channels finish",
         %{
           connection_id: connection_id,
           channels: channels
         } = context do
      flush(context)

      Dispatcher.dispatch(
        Event.new(nil, %Saga.Finish{
          id: channels.a.saga_id
        })
      )

      assert_receive %Event{
        body: %Saga.Finished{
          id: ^connection_id
        }
      }

      refute_receive %Event{}
    end
  end

  test "finishes when one or more channels are already finished" do
    message = %Message{
      event: Event.new(nil, %TestEvent{}),
      destination_saga_id: SagaID.new(),
      destination_saga_module: TestSaga
    }

    channel_a = %Channel{
      # Not launched
      saga_id: SagaID.new(),
      saga_module: ChannelA
    }

    saga_id = SagaID.new()
    Dispatcher.listen_event_body(%Saga.Finish{id: saga_id})

    Dispatcher.dispatch(
      Event.new(nil, %SagaLauncher.LaunchSaga{
        id: saga_id,
        saga: %Connection{
          message: message,
          channels: [channel_a]
        }
      })
    )

    assert_receive %Event{
      body: %Saga.Finish{
        id: ^saga_id
      }
    }
  end

  defp flush(%{
         connection_id: connection_id,
         message: message,
         channels: channels
       }) do
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
  end
end
