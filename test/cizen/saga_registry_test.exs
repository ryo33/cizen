defmodule Cizen.SagaRegistryTest do
  use Cizen.SagaCase
  doctest Cizen.SagaRegistry
  import Cizen.TestHelper, only: [launch_test_saga: 0, assert_condition: 2]

  alias Cizen.SagaRegistry

  describe "get_pid/1" do
    test "launched saga is registered" do
      id = launch_test_saga()
      assert {:ok, pid} = SagaRegistry.get_pid(id)
    end

    test "killed saga is unregistered" do
      id = launch_test_saga()
      assert {:ok, pid} = SagaRegistry.get_pid(id)
      true = Process.exit(pid, :kill)
      assert_condition(100, :error == SagaRegistry.get_pid(id))
    end
  end

  defmodule TestSaga do
    @behaviour Cizen.Saga
    defstruct [:value]
    @impl true
    def init(_id, %__MODULE__{}) do
      :ok
    end
    @impl true
    def handle_event(_id, _event, :ok) do
      :ok
    end
  end

  describe "get_saga/1" do
    test "returns a saga struct" do
      assert_handle(fn id ->
        use Cizen.Effects
        id =
          perform id, %Start{
            saga: %TestSaga{value: :some_value}
          }
        assert {:ok, %TestSaga{value: :some_value}} = SagaRegistry.get_saga(id)
      end)
    end

    test "returns error for unregistered saga" do
    end
  end
end
