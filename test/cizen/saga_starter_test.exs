defmodule Cizen.SagaStarterTest do
  use Cizen.SagaCase
  alias Cizen.Test
  alias Cizen.TestHelper
  alias Cizen.TestSaga

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.Saga
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

      lifetime = TestHelper.launch_test_saga()
      {:ok, lifetime_pid} = Saga.get_pid(lifetime)

      saga_id = SagaID.new()

      Dispatcher.dispatch(
        Event.new(nil, %StartSaga{
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

    test "does not dispatch LaunchSaga event when lifetime is finished" do
      Dispatcher.listen_event_type(LaunchSaga)

      lifetime = TestHelper.launch_test_saga()
      {:ok, lifetime_pid} = Saga.get_pid(lifetime)
      Test.ensure_finished(lifetime)

      saga_id = SagaID.new()

      Dispatcher.dispatch(
        Event.new(nil, %StartSaga{
          id: saga_id,
          saga: %TestSaga{},
          lifetime_saga_id: lifetime
        })
      )

      refute_receive %Event{
        body: %LaunchSaga{
          id: ^saga_id,
          saga: %TestSaga{},
          lifetime_pid: ^lifetime_pid
        }
      }
    end
  end
end
