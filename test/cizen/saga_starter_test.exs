defmodule Cizen.SagaStarterTest do
  use Cizen.SagaCase
  alias Cizen.TestSaga

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.SagaID

  alias Cizen.SagaLauncher.LaunchSaga
  alias Cizen.StartSaga

  describe "SagaStarter" do
    test "dispatches LaunchSaga event on StartSaga event" do
      Dispatcher.listen_event_type(LaunchSaga)

      saga_id = SagaID.new()

      Dispatcher.dispatch(
        Event.new(nil, %StartSaga{
          id: saga_id,
          saga: %TestSaga{}
        })
      )

      assert_receive %Event{
        body: %LaunchSaga{
          id: ^saga_id,
          saga: %TestSaga{},
          lifetime_pid: nil
        }
      }
    end

    test "dispatches LaunchSaga event on StartSaga event with lifetime" do
      Dispatcher.listen_event_type(LaunchSaga)

      lifetime =
        spawn(fn ->
          receive do
            _ -> :ok
          end
        end)

      saga_id = SagaID.new()

      Dispatcher.dispatch(
        Event.new(nil, %StartSaga{
          id: saga_id,
          saga: %TestSaga{},
          lifetime_pid: lifetime
        })
      )

      assert_receive %Event{
        body: %LaunchSaga{
          id: ^saga_id,
          saga: %TestSaga{},
          lifetime_pid: ^lifetime
        }
      }
    end
  end
end
