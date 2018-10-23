defmodule Cizen.SagaFilterTest do
  use ExUnit.Case

  defmodule TestSaga do
    @behaviour Cizen.Saga
    defstruct [:some_key]

    import Cizen.SagaFilter
    defsagafilter SomeKeyFilter, :some_key

    defsagafilter WithBlock, :some_key do
      def some_function, do: :defined
    end

    @impl true
    def init(_id, _saga) do
      :ok
    end

    @impl true
    def handle_event(_id, _event, state) do
      state
    end
  end

  defp setup_filter(_context) do
    %{filter: %TestSaga.SomeKeyFilter{value: :a}}
  end

  describe "SagaFilter.defsagafilter" do
    setup [:setup_filter]

    alias Cizen.SagaFilter

    test "matches", %{filter: filter} do
      assert SagaFilter.test(filter, %TestSaga{some_key: :a})
    end

    test "does not matches", %{filter: filter} do
      refute SagaFilter.test(filter, %TestSaga{some_key: :b})
    end

    test "uses the do block" do
      alias TestSaga.WithBlock
      assert :defined == WithBlock.some_function()
    end
  end
end
