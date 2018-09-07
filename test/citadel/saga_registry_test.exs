defmodule Citadel.SagaRegistryTest do
  use ExUnit.Case
  doctest Citadel.SagaRegistry
  import Citadel.TestHelper, only: [launch_test_saga: 0]

  import Citadel.Dispatcher, only: [dispatch: 1]
  alias Citadel.Event
  alias Citadel.SagaLauncher
  alias Citadel.SagaRegistry

  test "launched saga is registered" do
    id = launch_test_saga()
    assert {:ok, pid} = SagaRegistry.resolve_id(id)
  end

  test "killed saga is unregistered" do
    id = launch_test_saga()
    assert {:ok, pid} = SagaRegistry.resolve_id(id)
    true = Process.exit(pid, :kill)
    dispatch(Event.new(%SagaLauncher.UnlaunchSaga{id: id}))
    :timer.sleep(100)
    assert :error = SagaRegistry.resolve_id(id)
  end
end
