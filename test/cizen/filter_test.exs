defmodule Cizen.FilterTest do
  use ExUnit.Case

  alias Cizen.Filter
  require Cizen.Filter

  defmodule(A, do: defstruct([:key1, :key2]))
  defmodule(B, do: defstruct([:key1, :key2, :a]))
  defmodule(C, do: defstruct([:key1, :key2, :b]))

  test "throw exception on a wrong struct destructure" do
    assert_raise CompileError, fn ->
      quoted =
        quote do
          Filter.new(fn %A{key1: a, key2: b, key3: c} ->
            a + b + c == 3
          end)
        end

      Code.eval_quoted(quoted, [], __ENV__)
    end
  end

  test "checks type" do
    filter = Filter.new(fn %A{key1: a} -> a == "a" end)
    assert Filter.match?(filter, %A{key1: "a"})
    refute Filter.match?(filter, %B{key1: "a"})
  end

  test "all/1" do
    filter_3 = Filter.new(fn %A{key1: a} -> rem(a, 3) == 0 end)
    filter_5 = Filter.new(fn %A{key1: a} -> rem(a, 5) == 0 end)
    filter = Filter.all([filter_3, filter_5])
    assert Filter.match?(filter, %A{key1: 15})
    refute Filter.match?(filter, %A{key1: 5})
    refute Filter.match?(filter, %A{key1: 3})
    refute Filter.match?(filter, %A{key1: 1})
  end

  test "all/1 with an empty list" do
    filter = Filter.all([])
    assert Filter.match?(filter, %A{})
    assert Filter.match?(filter, nil)
  end

  test "any/1" do
    filter_3 = Filter.new(fn %A{key1: a} -> rem(a, 3) == 0 end)
    filter_5 = Filter.new(fn %A{key1: a} -> rem(a, 5) == 0 end)
    filter = Filter.any([filter_3, filter_5])
    assert Filter.match?(filter, %A{key1: 15})
    assert Filter.match?(filter, %A{key1: 5})
    assert Filter.match?(filter, %A{key1: 3})
    refute Filter.match?(filter, %A{key1: 1})
  end

  test "any/1 with an empty list" do
    filter = Filter.any([])
    refute Filter.match?(filter, %A{})
    refute Filter.match?(filter, true)
  end

  test "eval value" do
    assert Filter.eval("a", %A{}) == "a"
  end

  test "eval access" do
    filter =
      Filter.new(fn %C{b: %B{a: %A{key2: c}}} ->
        c
      end)

    assert Filter.eval(filter.code, %C{b: %B{a: %A{key2: "a"}}}) == "a"
  end

  test "eval root access" do
    filter =
      Filter.new(fn a ->
        a
      end)

    assert Filter.eval(filter.code, %A{key1: "a"}) == %A{key1: "a"}
  end

  test "eval call" do
    filter =
      Filter.new(fn %A{key1: a} ->
        Enum.count(a)
      end)

    assert Filter.eval(filter.code, %A{key1: [1, 2, 3]}) == 3
  end

  test "eval is_nil" do
    filter =
      Filter.new(fn %A{key1: a} ->
        is_nil(a)
      end)

    assert Filter.eval(filter.code, %A{key1: :a}) == false
    assert Filter.eval(filter.code, %A{key1: nil}) == true
  end

  test "eval and" do
    filter =
      Filter.new(fn %A{key1: a, key2: b} ->
        a and b
      end)

    assert Filter.eval(filter.code, %A{key1: true, key2: true}) == true
    assert Filter.eval(filter.code, %A{key1: true, key2: false}) == false
    assert Filter.eval(filter.code, %A{key1: false, key2: true}) == false
    assert Filter.eval(filter.code, %A{key1: false, key2: false}) == false
  end

  test "eval or" do
    filter =
      Filter.new(fn %A{key1: a, key2: b} ->
        a or b
      end)

    assert Filter.eval(filter.code, %A{key1: true, key2: true}) == true
    assert Filter.eval(filter.code, %A{key1: true, key2: false}) == true
    assert Filter.eval(filter.code, %A{key1: false, key2: true}) == true
    assert Filter.eval(filter.code, %A{key1: false, key2: false}) == false
  end

  test "eval operators" do
    filter =
      Filter.new(fn %A{key1: a} ->
        a * 2 == 42
      end)

    assert Filter.eval(filter.code, %A{key1: 21}) == true
    assert Filter.eval(filter.code, %A{key1: 1}) == false
  end
end
