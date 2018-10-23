defmodule Cizen.SagaFilterSetTest do
  use ExUnit.Case

  alias Cizen.SagaFilter
  alias Cizen.SagaFilterSet

  defmodule(A, do: defstruct([:value]))
  defmodule(B, do: defstruct([:value]))

  test "Two sets should equal when both have the same list." do
    assert SagaFilterSet.new([%A{value: :a}, %B{value: :b}]) ==
             SagaFilterSet.new([%A{value: :a}, %B{value: :b}])
  end

  test "Two sets should not equal when they have not shared items." do
    assert SagaFilterSet.new([%A{value: :a}, %B{value: :b}]) !=
             SagaFilterSet.new([%A{value: :a}, {C, :c}])
  end

  test "Two sets should equal even if one's order of list isn't the same as other's one." do
    assert SagaFilterSet.new([%A{value: :a}, %B{value: :b}]) ==
             SagaFilterSet.new([%B{value: :b}, %A{value: :a}])
  end

  defmodule TestSaga do
    @behaviour Cizen.Saga
    defstruct [:value_a, :value_b]

    @impl true
    def init(_id, _saga) do
      :ok
    end

    @impl true
    def handle_event(_id, _event, state) do
      state
    end
  end

  defmodule TestSagaFilterA do
    @behaviour SagaFilter
    defstruct [:value]
    @impl true
    def test(%__MODULE__{value: value}, %TestSaga{value_a: value}), do: true
    def test(_, _), do: false
  end

  defmodule TestSagaFilterB do
    @behaviour SagaFilter
    defstruct [:value]
    @impl true
    def test(%__MODULE__{value: value}, %TestSaga{value_b: value}), do: true
    def test(_, _), do: false
  end

  describe "test/2" do
    test "return true when all filters return true" do
      assert SagaFilterSet.test(
               SagaFilterSet.new([
                 %TestSagaFilterA{value: :a},
                 %TestSagaFilterB{value: :b}
               ]),
               %TestSaga{
                 value_a: :a,
                 value_b: :b
               }
             )
    end

    test "return false one or more filters return false" do
      refute SagaFilterSet.test(
               SagaFilterSet.new([
                 %TestSagaFilterA{value: :a},
                 %TestSagaFilterB{value: :b}
               ]),
               %TestSaga{
                 value_a: :c,
                 value_b: :b
               }
             )

      refute SagaFilterSet.test(
               SagaFilterSet.new([
                 %TestSagaFilterA{value: :a},
                 %TestSagaFilterB{value: :b}
               ]),
               %TestSaga{
                 value_a: :c,
                 value_b: :c
               }
             )
    end
  end
end
