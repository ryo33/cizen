defmodule Citadel.SagaStarterTest do
  use ExUnit.Case
  alias Citadel.TestHelper
  alias Citadel.TestSaga

  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.SagaID

  alias Citadel.SagaLauncher.LaunchSaga
  alias Citadel.StartSaga

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

      TestHelper.ensure_finished(saga_id)
    end
  end
end
