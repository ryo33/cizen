defmodule Cizen.StartSagaTest do
  use ExUnit.Case
  alias Cizen.TestSaga

  alias Cizen.EventBodyFilter
  alias Cizen.SagaID

  alias Cizen.StartSaga

  defmodule(TestSaga, do: defstruct([:value]))

  describe "StartSaga.SagaModuleFilter" do
    test "returns true if the saga module is matched" do
      filter = %StartSaga.SagaModuleFilter{value: TestSaga}
      body = %StartSaga{id: SagaID.new(), saga: %TestSaga{}}
      assert EventBodyFilter.test(filter, body)
    end

    test "returns false if the saga module is not matched" do
      filter = %StartSaga.SagaModuleFilter{value: UnknownSaga}
      body = %StartSaga{id: SagaID.new(), saga: %TestSaga{}}
      refute EventBodyFilter.test(filter, body)
    end
  end

  describe "StartSaga.SagaFilter" do
    test "returns true if the saga struct is matched" do
      filter = %StartSaga.SagaFilter{value: %TestSaga{value: :a}}
      body = %StartSaga{id: SagaID.new(), saga: %TestSaga{value: :a}}
      assert EventBodyFilter.test(filter, body)
    end

    test "returns false if the saga struct is not matched" do
      filter = %StartSaga.SagaFilter{value: %TestSaga{value: :b}}
      body = %StartSaga{id: SagaID.new(), saga: %TestSaga{value: :a}}
      refute EventBodyFilter.test(filter, body)
    end
  end
end
