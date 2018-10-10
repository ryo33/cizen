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
        Event.new(%StartSaga{
          id: saga_id,
          saga: %TestSaga{}
        })
      )

      assert_receive %Event{
        body: %LaunchSaga{
          id: ^saga_id,
          saga: %TestSaga{}
        }
      }
    end
  end
end
