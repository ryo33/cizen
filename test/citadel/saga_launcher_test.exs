defmodule Citadel.SagaLauncherTest do
  use Citadel.SagaCase
  doctest Citadel.SagaLauncher
  import Citadel.TestHelper, only: [launch_test_saga: 0, assert_condition: 2]

  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.SagaID
  alias Citadel.SagaLauncher
  alias Citadel.SagaRegistry
  alias Citadel.TestSaga

  test "SagaLauncher.LaunchSaga event" do
    pid = self()
    saga_id = SagaID.new()

    Dispatcher.dispatch(
      Event.new(%SagaLauncher.LaunchSaga{
        id: saga_id,
        saga: %TestSaga{
          launch: fn id, _state ->
            send(pid, {:ok, id})
          end
        }
      })
    )

    assert_receive {:ok, saga_id}
  end

  test "SagaLauncher.UnlaunchSaga event" do
    id = launch_test_saga()
    assert {:ok, pid} = SagaRegistry.resolve_id(id)
    Dispatcher.dispatch(Event.new(%SagaLauncher.UnlaunchSaga{id: id}))
    assert_condition(100, Process.alive?(pid))
  end
end
