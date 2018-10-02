defmodule Citadel.TransmitterTest do
  use ExUnit.Case
  alias Citadel.TestHelper

  alias Citadel.Channel
  alias Citadel.Connection
  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.Message
  alias Citadel.Saga
  alias Citadel.SagaID
  alias Citadel.SagaLauncher

  alias Citadel.ReceiveMessage
  alias Citadel.SendMessage

  defmodule(TestEvent, do: defstruct([:value]))

  test "Launch Connection saga on SendMessage event" do
    Dispatcher.listen_event_type(SagaLauncher.LaunchSaga)
    Dispatcher.listen_event_type(Saga.Launched)

    message = %Message{
      event: Event.new(%TestEvent{}),
      destination_saga_id: SagaID.new(),
      destination_saga_module: TestSaga
    }

    channels = [
      %Channel{saga_id: SagaID.new(), saga_module: TestChannel}
    ]

    Dispatcher.dispatch(
      Event.new(%SendMessage{
        message: message,
        channels: channels
      })
    )

    receive do
      event ->
        saga_id = event.body.id

        assert %Event{
                 body: %SagaLauncher.LaunchSaga{
                   saga: %Connection{
                     message: ^message,
                     channels: ^channels
                   }
                 }
               } = event

        assert_receive %Event{body: %Saga.Launched{id: ^saga_id}}
        TestHelper.ensure_finished(saga_id)
    after
      100 -> flunk("timeout")
    end
  end

  test "send the message to destination saga on SendMessage event" do
    pid = self()

    saga_id =
      TestHelper.launch_test_saga(handle_event: fn _id, event, _state -> send(pid, event) end)

    message = %Message{
      event: Event.new(%TestEvent{}),
      destination_saga_id: saga_id,
      destination_saga_module: TestSaga
    }

    event =
      Event.new(%ReceiveMessage{
        message: message
      })

    Dispatcher.dispatch(event)

    assert_receive ^event
  end
end
