defmodule Cizen.SagaStarterTest do
  use Cizen.SagaCase
  alias Cizen.TestHelper
  alias Cizen.TestSaga

  alias Cizen.CizenSagaRegistry
  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.SagaID

  alias Cizen.SagaLauncher.LaunchSaga

  alias Cizen.ForkSaga
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

    test "dispatches LaunchSaga event on ForkSaga event" do
      Dispatcher.listen_event_type(LaunchSaga)

      lifetime = TestHelper.launch_test_saga()
      {:ok, lifetime_pid} = CizenSagaRegistry.get_pid(lifetime)

      saga_id = SagaID.new()

      Dispatcher.dispatch(
        Event.new(nil, %ForkSaga{
          id: saga_id,
          saga: %TestSaga{},
          lifetime_saga_id: lifetime
        })
      )

      assert_receive %Event{
        body: %LaunchSaga{
          id: ^saga_id,
          saga: %TestSaga{},
          lifetime_pid: ^lifetime_pid
        }
      }
    end
  end
end
