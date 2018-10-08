defmodule Citadel.SagaRegistryTest do
  use Citadel.SagaCase
  doctest Citadel.SagaRegistry
  import Citadel.TestHelper, only: [launch_test_saga: 0, assert_condition: 2]

  alias Citadel.SagaRegistry

  test "launched saga is registered" do
    id = launch_test_saga()
    assert {:ok, pid} = SagaRegistry.resolve_id(id)
  end

  test "killed saga is unregistered" do
    id = launch_test_saga()
    assert {:ok, pid} = SagaRegistry.resolve_id(id)
    true = Process.exit(pid, :kill)
    assert_condition(100, :error == SagaRegistry.resolve_id(id))
  end
end
