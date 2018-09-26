defmodule Citadel.FilterSetTest do
  use ExUnit.Case
  alias Citadel.FilterSet

  test "Two sets should equal when both have the same list." do
    assert FilterSet.new([{A, :a}, {B, :b}]) == FilterSet.new([{A, :a}, {B, :b}])
  end

  test "Two sets should not equal when they have not shared items." do
    refute FilterSet.new([{A, :a}, {B, :b}]) == FilterSet.new([{A, :a}, {C, :c}])
  end

  test "Two sets should equal even if one's order of list isn't the same as other's one." do
    assert FilterSet.new([{A, :a}, {B, :b}]) == FilterSet.new([{B, :b}, {A, :a}])
  end
end
