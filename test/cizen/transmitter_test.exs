defmodule Cizen.TransmitterTest do
  use Cizen.SagaCase
  alias Cizen.TestHelper

  alias Cizen.Channel
  alias Cizen.Connection
  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.Message
  alias Cizen.Saga
  alias Cizen.SagaID
  alias Cizen.SagaLauncher

  alias Cizen.ReceiveMessage
  alias Cizen.SendMessage

  defmodule(TestEvent, do: defstruct([:value]))

  test "Launch Connection saga on SendMessage event" do
    Dispatcher.listen_event_type(SagaLauncher.LaunchSaga)
    Dispatcher.listen_event_type(Saga.Launched)

    message = %Message{
      event: Event.new(nil, %TestEvent{}),
      destination_saga_id: SagaID.new(),
      destination_saga_module: TestSaga
    }

    channels = [
      %Channel{saga_id: SagaID.new(), saga_module: TestChannel}
    ]

    Dispatcher.dispatch(
      Event.new(nil, %SendMessage{
        message: message,
        channels: channels
      })
    )

    event =
      assert_receive %Event{
        body: %SagaLauncher.LaunchSaga{
          saga: %Connection{
            message: ^message,
            channels: ^channels
          }
        }
      }

    saga_id = event.body.id
    assert_receive %Event{body: %Saga.Launched{id: ^saga_id}}
  end

  test "dispatch ReceiveMessage immediately if there is no channels" do
    Dispatcher.listen_event_type(SagaLauncher.LaunchSaga)
    Dispatcher.listen_event_type(ReceiveMessage)

    message = %Message{
      event: Event.new(nil, %TestEvent{}),
      destination_saga_id: SagaID.new(),
      destination_saga_module: TestSaga
    }

    channels = []

    Dispatcher.dispatch(
      Event.new(nil, %SendMessage{
        message: message,
        channels: channels
      })
    )

    refute_receive %Event{
      body: %SagaLauncher.LaunchSaga{
        saga: %Connection{
          message: ^message,
          channels: ^channels
        }
      }
    }

    assert_receive %Event{
      body: %ReceiveMessage{
        message: ^message
      }
    }
  end

  test "send the message to destination saga on ReceiveMessage event" do
    pid = self()

    saga_id =
      TestHelper.launch_test_saga(handle_event: fn _id, event, _state -> send(pid, event) end)

    message = %Message{
      event: Event.new(nil, %TestEvent{}),
      destination_saga_id: saga_id,
      destination_saga_module: TestSaga
    }

    event =
      Event.new(nil, %ReceiveMessage{
        message: message
      })

    Dispatcher.dispatch(event)

    assert_receive ^event
  end
end
