defmodule Citadel.SagaLauncherTest do
  use ExUnit.Case
  doctest Citadel.SagaLauncher
  import Citadel.TestHelper, only: [launch_test_saga: 0, assert_condition: 2]

  import Citadel.Dispatcher, only: [dispatch: 1]
  alias Citadel.Event
  alias Citadel.SagaID
  alias Citadel.SagaLauncher
  alias Citadel.SagaRegistry
  alias Citadel.TestHelper
  alias Citadel.TestSaga

  test "SagaLauncher.LaunchSaga event" do
    pid = self()
    saga_id = SagaID.new()

    dispatch(
      Event.new(%SagaLauncher.LaunchSaga{
        id: saga_id,
        module: TestSaga,
        state: %{
          launch: fn id, _state ->
            send(pid, {:ok, id})
          end
        }
      })
    )

    assert_receive {:ok, saga_id}

    TestHelper.ensure_finished(saga_id)
  end

  test "SagaLauncher.UnlaunchSaga event" do
    id = launch_test_saga()
    assert {:ok, pid} = SagaRegistry.resolve_id(id)
    dispatch(Event.new(%SagaLauncher.UnlaunchSaga{id: id}))
    assert_condition(100, Process.alive?(pid))
  end
end
