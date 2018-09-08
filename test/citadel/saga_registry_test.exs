defmodule Citadel.SagaRegistryTest do
  use ExUnit.Case
  doctest Citadel.SagaRegistry
  import Citadel.TestHelper, only: [launch_test_saga: 0]

  alias Citadel.SagaRegistry

  test "launched saga is registered" do
    id = launch_test_saga()
    assert {:ok, pid} = SagaRegistry.resolve_id(id)
  end

  test "killed saga is unregistered" do
    id = launch_test_saga()
    assert {:ok, pid} = SagaRegistry.resolve_id(id)
    true = Process.exit(pid, :kill)
    :timer.sleep(100)
    assert :error = SagaRegistry.resolve_id(id)
  end
end
