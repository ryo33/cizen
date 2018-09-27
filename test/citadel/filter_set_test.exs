defmodule Citadel.FilterSetTest do
  use ExUnit.Case

  alias Citadel.Event
  alias Citadel.Filter
  alias Citadel.FilterSet

  test "Two sets should equal when both have the same list." do
    assert FilterSet.new(T, [{A, :a}, {B, :b}]) == FilterSet.new(T, [{A, :a}, {B, :b}])
  end

  test "Two sets should not equal when they have not shared items." do
    assert FilterSet.new(T, [{A, :a}, {B, :b}]) != FilterSet.new(T, [{A, :a}, {C, :c}])
  end

  test "Two sets should equal even if one's order of list isn't the same as other's one." do
    assert FilterSet.new(T, [{A, :a}, {B, :b}]) == FilterSet.new(T, [{B, :b}, {A, :a}])
  end

  defmodule(TestEvent, do: defstruct([:value_a, :value_b]))

  defmodule TestFilterA do
    @behaviour Filter
    @impl true
    def test(%Event{body: %TestEvent{value_a: value}}, opts), do: value == opts
    def test(_, _), do: false
  end

  defmodule TestFilterB do
    @behaviour Filter
    @impl true
    def test(%Event{body: %TestEvent{value_b: value}}, opts), do: value == opts
    def test(_, _), do: false
  end

  describe "test/2" do
    test "matches" do
      assert FilterSet.test(
               FilterSet.new(TestEvent, [
                 Filter.new(TestFilterA, :a),
                 Filter.new(TestFilterB, :b)
               ]),
               Event.new(%TestEvent{
                 value_a: :a,
                 value_b: :b
               })
             )
    end

    test "does not match when the target event type is miss matched" do
      refute FilterSet.test(
               FilterSet.new(UnknownEvent, [
                 Filter.new(TestFilterA, :a),
                 Filter.new(TestFilterB, :b)
               ]),
               Event.new(%TestEvent{
                 value_a: :a,
                 value_b: :b
               })
             )
    end

    test "does not match when one or more filters return false" do
      refute FilterSet.test(
               FilterSet.new(TestEvent, [
                 Filter.new(TestFilterA, :a),
                 Filter.new(TestFilterB, :b)
               ]),
               Event.new(%TestEvent{
                 value_a: :c,
                 value_b: :b
               })
             )

      refute FilterSet.test(
               FilterSet.new(TestEvent, [
                 Filter.new(TestFilterA, :a),
                 Filter.new(TestFilterB, :b)
               ]),
               Event.new(%TestEvent{
                 value_a: :c,
                 value_b: :c
               })
             )
    end
  end
end
