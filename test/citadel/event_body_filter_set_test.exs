defmodule Cizen.EventBodyFilterSetTest do
  use ExUnit.Case

  alias Cizen.EventBodyFilter
  alias Cizen.EventBodyFilterSet

  defmodule(A, do: defstruct([:value]))
  defmodule(B, do: defstruct([:value]))

  test "Two sets should equal when both have the same list." do
    assert EventBodyFilterSet.new([%A{value: :a}, %B{value: :b}]) ==
             EventBodyFilterSet.new([%A{value: :a}, %B{value: :b}])
  end

  test "Two sets should not equal when they have not shared items." do
    assert EventBodyFilterSet.new([%A{value: :a}, %B{value: :b}]) !=
             EventBodyFilterSet.new([%A{value: :a}, {C, :c}])
  end

  test "Two sets should equal even if one's order of list isn't the same as other's one." do
    assert EventBodyFilterSet.new([%A{value: :a}, %B{value: :b}]) ==
             EventBodyFilterSet.new([%B{value: :b}, %A{value: :a}])
  end

  defmodule(TestEvent, do: defstruct([:value_a, :value_b]))

  defmodule TestEventBodyFilterA do
    @behaviour EventBodyFilter
    defstruct [:value]
    @impl true
    def test(%__MODULE__{value: value}, %TestEvent{value_a: value}), do: true
    def test(_, _), do: false
  end

  defmodule TestEventBodyFilterB do
    @behaviour EventBodyFilter
    defstruct [:value]
    @impl true
    def test(%__MODULE__{value: value}, %TestEvent{value_b: value}), do: true
    def test(_, _), do: false
  end

  describe "test/2" do
    test "return true when all filters return true" do
      assert EventBodyFilterSet.test(
               EventBodyFilterSet.new([
                 %TestEventBodyFilterA{value: :a},
                 %TestEventBodyFilterB{value: :b}
               ]),
               %TestEvent{
                 value_a: :a,
                 value_b: :b
               }
             )
    end

    test "return false one or more filters return false" do
      refute EventBodyFilterSet.test(
               EventBodyFilterSet.new([
                 %TestEventBodyFilterA{value: :a},
                 %TestEventBodyFilterB{value: :b}
               ]),
               %TestEvent{
                 value_a: :c,
                 value_b: :b
               }
             )

      refute EventBodyFilterSet.test(
               EventBodyFilterSet.new([
                 %TestEventBodyFilterA{value: :a},
                 %TestEventBodyFilterB{value: :b}
               ]),
               %TestEvent{
                 value_a: :c,
                 value_b: :c
               }
             )
    end
  end
end
