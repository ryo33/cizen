defmodule Cizen.SagaLauncherTest do
  use Cizen.SagaCase
  doctest Cizen.SagaLauncher
  import Cizen.TestHelper, only: [launch_test_saga: 0, assert_condition: 2]

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.SagaID
  alias Cizen.SagaLauncher
  alias Cizen.SagaRegistry
  alias Cizen.TestSaga

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
    assert {:ok, pid} = SagaRegistry.get_pid(id)
    Dispatcher.dispatch(Event.new(%SagaLauncher.UnlaunchSaga{id: id}))
    assert_condition(100, Process.alive?(pid))
  end
end
