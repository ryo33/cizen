defmodule Citadel.EventBodyFilterSetTest do
  use ExUnit.Case

  alias Citadel.EventBodyFilter
  alias Citadel.EventBodyFilterSet

  test "Two sets should equal when both have the same list." do
    assert EventBodyFilterSet.new([{A, :a}, {B, :b}]) ==
             EventBodyFilterSet.new([{A, :a}, {B, :b}])
  end

  test "Two sets should not equal when they have not shared items." do
    assert EventBodyFilterSet.new([{A, :a}, {B, :b}]) !=
             EventBodyFilterSet.new([{A, :a}, {C, :c}])
  end

  test "Two sets should equal even if one's order of list isn't the same as other's one." do
    assert EventBodyFilterSet.new([{A, :a}, {B, :b}]) ==
             EventBodyFilterSet.new([{B, :b}, {A, :a}])
  end

  defmodule(TestEvent, do: defstruct([:value_a, :value_b]))

  defmodule TestEventBodyFilterA do
    @behaviour EventBodyFilter
    @impl true
    def test(%TestEvent{value_a: value}, opts), do: value == opts
  end

  defmodule TestEventBodyFilterB do
    @behaviour EventBodyFilter
    @impl true
    def test(%TestEvent{value_b: value}, opts), do: value == opts
  end

  describe "test/2" do
    test "return true when all filters return true" do
      assert EventBodyFilterSet.test(
               EventBodyFilterSet.new([
                 EventBodyFilter.new(TestEventBodyFilterA, :a),
                 EventBodyFilter.new(TestEventBodyFilterB, :b)
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
                 EventBodyFilter.new(TestEventBodyFilterA, :a),
                 EventBodyFilter.new(TestEventBodyFilterB, :b)
               ]),
               %TestEvent{
                 value_a: :c,
                 value_b: :b
               }
             )

      refute EventBodyFilterSet.test(
               EventBodyFilterSet.new([
                 EventBodyFilter.new(TestEventBodyFilterA, :a),
                 EventBodyFilter.new(TestEventBodyFilterB, :b)
               ]),
               %TestEvent{
                 value_a: :c,
                 value_b: :c
               }
             )
    end
  end
end
