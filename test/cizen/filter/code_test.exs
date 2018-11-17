defmodule Cizen.Filter.CodeTest do
  use ExUnit.Case

  alias Cizen.Filter
  require Cizen.Filter

  defmodule(A, do: defstruct([:key1, :key2, :b]))
  defmodule(B, do: defstruct([:key1, :key2, :a]))
  defmodule(C, do: defstruct([:key1, :key2, :b]))

  test "creates a filter with is_nil" do
    filter =
      Filter.new(fn %A{key1: a} ->
        is_nil(a)
      end)

    assert {:and,
            [
              {:and, [{:is_map, [{:access, []}]}, {:==, [{:access, [:__struct__]}, A]}]},
              {:is_nil, [{:access, [:key1]}]}
            ]} == filter.code
  end

  test "creates a filter with to_string" do
    filter =
      Filter.new(fn %A{key1: a} ->
        to_string(a)
      end)

    assert {:and,
            [
              {:and, [{:is_map, [{:access, []}]}, {:==, [{:access, [:__struct__]}, A]}]},
              {:to_string, [{:access, [:key1]}]}
            ]} == filter.code
  end

  test "creates a filter with to_charlist" do
    filter =
      Filter.new(fn %A{key1: a} ->
        to_charlist(a)
      end)

    assert {:and,
            [
              {:and, [{:is_map, [{:access, []}]}, {:==, [{:access, [:__struct__]}, A]}]},
              {:to_charlist, [{:access, [:key1]}]}
            ]} == filter.code
  end

  test "creates a filter with arguments" do
    value1 = "value1"
    filter = Filter.new(fn %A{key1: a} -> a == value1 end)

    assert {:and,
            [
              {:and, [{:is_map, [{:access, []}]}, {:==, [{:access, [:__struct__]}, A]}]},
              {:==, [{:access, [:key1]}, "value1"]}
            ]} == filter.code
  end

  test "nested filter" do
    filter =
      Filter.new(fn %C{key1: a, b: %B{key1: b, a: %A{key2: c}}} ->
        a == "a" and b == "b" and c == "c"
      end)

    expected =
      {:and,
       [
         {:and,
          [
            {:and, [{:is_map, [{:access, []}]}, {:==, [{:access, [:__struct__]}, C]}]},
            {:and,
             [
               {:and, [{:is_map, [{:access, [:b]}]}, {:==, [{:access, [:b, :__struct__]}, B]}]},
               {:and,
                [{:is_map, [{:access, [:b, :a]}]}, {:==, [{:access, [:b, :a, :__struct__]}, A]}]}
             ]}
          ]},
         {:and,
          [
            {:and,
             [
               {:==, [{:access, [:key1]}, "a"]},
               {:==, [{:access, [:b, :key1]}, "b"]}
             ]},
            {:==, [{:access, [:b, :a, :key2]}, "c"]}
          ]}
       ]}

    assert expected == filter.code
  end

  test "embedded filter" do
    b_filter =
      Filter.new(fn %B{key1: a, a: %A{key2: b}} ->
        a == "b" and b == "c"
      end)

    filter =
      Filter.new(fn %C{key1: a, b: b} ->
        a == "a" and Filter.match?(b_filter, b)
      end)

    assert {:and,
            [
              {:and, [{:is_map, [{:access, []}]}, {:==, [{:access, [:__struct__]}, C]}]},
              {:and,
               [
                 {:==, [{:access, [:key1]}, "a"]},
                 {:and,
                  [
                    {:and,
                     [
                       {:and,
                        [{:is_map, [{:access, [:b]}]}, {:==, [{:access, [:b, :__struct__]}, B]}]},
                       {:and,
                        [
                          {:is_map, [{:access, [:b, :a]}]},
                          {:==, [{:access, [:b, :a, :__struct__]}, A]}
                        ]}
                     ]},
                    {:and,
                     [
                       {:==, [{:access, [:b, :key1]}, "b"]},
                       {:==, [{:access, [:b, :a, :key2]}, "c"]}
                     ]}
                  ]}
               ]}
            ]} == filter.code
  end

  test "embedded Filter.new" do
    filter =
      Filter.new(fn %C{key1: a, b: b} ->
        a == "a" and
          Filter.match?(
            Filter.new(fn %B{key1: a, a: %A{key2: b}} ->
              a == "b" and b == "c"
            end),
            b
          )
      end)

    assert {:and,
            [
              {:and, [{:is_map, [{:access, []}]}, {:==, [{:access, [:__struct__]}, C]}]},
              {:and,
               [
                 {:==, [{:access, [:key1]}, "a"]},
                 {:and,
                  [
                    {:and,
                     [
                       {:and,
                        [{:is_map, [{:access, [:b]}]}, {:==, [{:access, [:b, :__struct__]}, B]}]},
                       {:and,
                        [
                          {:is_map, [{:access, [:b, :a]}]},
                          {:==, [{:access, [:b, :a, :__struct__]}, A]}
                        ]}
                     ]},
                    {:and,
                     [
                       {:==, [{:access, [:b, :key1]}, "b"]},
                       {:==, [{:access, [:b, :a, :key2]}, "c"]}
                     ]}
                  ]}
               ]}
            ]} == filter.code
  end

  defmodule TestModule do
    def func(a, b), do: {a, b}
  end

  test "transforms module function calls" do
    c = "c"

    filter =
      Filter.new(fn %A{key1: a, key2: b} ->
        TestModule.func(c, "d") == TestModule.func(a, b)
      end)

    assert {:and,
            [
              {:and, [{:is_map, [{:access, []}]}, {:==, [{:access, [:__struct__]}, A]}]},
              {
                :==,
                [
                  {"c", "d"},
                  {:call, [{TestModule, :func}, {:access, [:key1]}, {:access, [:key2]}]}
                ]
              }
            ]} == filter.code
  end

  test "transforms local function calls" do
    defmodule TestLocalFunctionModule do
      def local_function(a, b), do: {a, b}

      def filter do
        c = "c"

        Filter.new(fn %A{key1: a, key2: b} ->
          local_function(local_function(a, "a"), b) == local_function(c, "d")
        end)
      end
    end

    assert {:and,
            [
              {:and, [{:is_map, [{:access, []}]}, {:==, [{:access, [:__struct__]}, A]}]},
              {:==,
               [
                 {:call,
                  [
                    {TestLocalFunctionModule, :local_function},
                    {:call,
                     [{TestLocalFunctionModule, :local_function}, {:access, [:key1]}, "a"]},
                    {:access, [:key2]}
                  ]},
                 {"c", "d"}
               ]}
            ]} == TestLocalFunctionModule.filter().code
  end

  test "transforms imported function calls" do
    c = "c"

    import TestModule

    filter =
      Filter.new(fn %A{key1: a, key2: b} ->
        func(func(a, "a"), b) == func(c, "d")
      end)

    assert {
             :and,
             [
               {:and, [{:is_map, [{:access, []}]}, {:==, [{:access, [:__struct__]}, A]}]},
               {:==,
                [
                  {:call,
                   [
                     {TestModule, :func},
                     {:call, [{TestModule, :func}, {:access, [:key1]}, "a"]},
                     {:access, [:key2]}
                   ]},
                  {"c", "d"}
                ]}
             ]
           } == filter.code
  end

  def test_fun(a, b, c, d, e), do: {a, b, c, d, e}

  test "use = in argument" do
    filter =
      Filter.new(fn %C{key1: a, b: %B{key1: b, a: %A{key2: c} = d}} = e ->
        test_fun(a, b, c, d, e)
      end)

    expected =
      {:and,
       [
         {:and,
          [
            {:and, [{:is_map, [{:access, []}]}, {:==, [{:access, [:__struct__]}, C]}]},
            {:and,
             [
               {:and, [{:is_map, [{:access, [:b]}]}, {:==, [{:access, [:b, :__struct__]}, B]}]},
               {:and,
                [{:is_map, [{:access, [:b, :a]}]}, {:==, [{:access, [:b, :a, :__struct__]}, A]}]}
             ]}
          ]},
         {:call,
          [
            {__MODULE__, :test_fun},
            {:access, [:key1]},
            {:access, [:b, :key1]},
            {:access, [:b, :a, :key2]},
            {:access, [:b, :a]},
            {:access, []}
          ]}
       ]}

    assert expected == filter.code
  end

  test "all/1" do
    a = {:access, [:a]}
    b = {:access, [:b]}
    c = {:access, [:c]}
    code = Filter.Code.all([a, b, c])
    assert {:and, [a, {:and, [b, c]}]} == code
  end

  test "all/1 with one" do
    a = {:access, [:a]}
    code = Filter.Code.all([a])
    assert a == code
  end

  test "all/1 with empty list" do
    code = Filter.Code.all([])
    assert true == code
  end

  test "any/1" do
    a = {:access, [:a]}
    b = {:access, [:b]}
    c = {:access, [:c]}
    code = Filter.Code.any([a, b, c])
    assert {:or, [a, {:or, [b, c]}]} == code
  end

  test "any/1 with one" do
    a = {:access, [:a]}
    code = Filter.Code.any([a])
    assert a == code
  end

  test "any/1 with empty list" do
    code = Filter.Code.any([])
    assert false == code
  end

  test "access fields with . operator" do
    filter =
      Filter.new(fn struct ->
        struct.key1.key2.key3
      end)

    assert {:access, [:key1, :key2, :key3]} == filter.code
  end

  test "access fields with [] operator" do
    key2 = :key2

    filter =
      Filter.new(fn struct ->
        struct[:key1][key2][:key3]
      end)

    assert {:access, [:key1, :key2, :key3]} == filter.code
  end

  test "access fields with both of . and []" do
    filter =
      Filter.new(fn struct ->
        struct.key1[:key2].key3 == struct[:key1].key2[:key3]
      end)

    assert {:==,
            [
              {:access, [:key1, :key2, :key3]},
              {:access, [:key1, :key2, :key3]}
            ]} == filter.code
  end

  test "create filter without :__block__" do
    filter =
      Filter.new(fn %A{key1: a} ->
        not a
      end)

    assert {:and,
            [
              {:and, [{:is_map, [{:access, []}]}, {:==, [{:access, [:__struct__]}, A]}]},
              {:not, [{:access, [:key1]}]}
            ]} == filter.code
  end

  test "inline operators" do
    value = "a"

    filter =
      Filter.new(fn %A{key1: a} ->
        is_nil(value) or true
      end)

    assert {:and,
            [
              {:and, [{:is_map, [{:access, []}]}, {:==, [{:access, [:__struct__]}, A]}]},
              true
            ]} == filter.code
  end

  test "value in match" do
    filter = Filter.new(fn %A{key1: 3, key2: %B{key1: 5}} -> true end)

    expected =
      {:and,
       [
         {:and, [{:is_map, [{:access, []}]}, {:==, [{:access, [:__struct__]}, A]}]},
         {:and,
          [
            {:==, [{:access, [:key1]}, 3]},
            {:and,
             [
               {:and,
                [{:is_map, [{:access, [:key2]}]}, {:==, [{:access, [:key2, :__struct__]}, B]}]},
               {:==, [{:access, [:key2, :key1]}, 5]}
             ]}
          ]}
       ]}

    assert expected == filter.code
  end

  test "match with pin operator" do
    a = 3
    b = 5
    filter = Filter.new(fn %A{key1: ^a, key2: %B{key1: ^b}} -> true end)

    expected =
      {:and,
       [
         {:and, [{:is_map, [{:access, []}]}, {:==, [{:access, [:__struct__]}, A]}]},
         {:and,
          [
            {:==, [{:access, [:key1]}, 3]},
            {:and,
             [
               {:and,
                [{:is_map, [{:access, [:key2]}]}, {:==, [{:access, [:key2, :__struct__]}, B]}]},
               {:==, [{:access, [:key2, :key1]}, 5]}
             ]}
          ]}
       ]}

    assert expected == filter.code
  end

  test "match with same values" do
    filter = Filter.new(fn %A{key1: a, key2: a, b: %B{key1: a}} -> true end)

    expected =
      {:and,
       [
         {:and, [{:is_map, [{:access, []}]}, {:==, [{:access, [:__struct__]}, A]}]},
         {:and,
          [
            {:==, [{:access, [:key2]}, {:access, [:key1]}]},
            {:and,
             [
               {:and, [{:is_map, [{:access, [:b]}]}, {:==, [{:access, [:b, :__struct__]}, B]}]},
               {:==, [{:access, [:b, :key1]}, {:access, [:key1]}]}
             ]}
          ]}
       ]}

    assert expected == filter.code
  end

  test "support multiple cases" do
    filter =
      Filter.new(fn
        %A{key1: a} ->
          a == "a"

        %B{key1: a, key2: "b"} ->
          call(a)

        %C{key1: a} ->
          call(a)
      end)

    expected =
      {:or,
       [
         {:and,
          [
            {:and, [{:is_map, [{:access, []}]}, {:==, [{:access, [:__struct__]}, A]}]},
            {:==, [{:access, [:key1]}, "a"]}
          ]},
         {:or,
          [
            {:and,
             [
               {:and,
                [
                  {:==,
                   [
                     {:and, [{:is_map, [{:access, []}]}, {:==, [{:access, [:__struct__]}, A]}]},
                     false
                   ]},
                  {:and,
                   [
                     {:and, [{:is_map, [{:access, []}]}, {:==, [{:access, [:__struct__]}, B]}]},
                     {:==, [{:access, [:key2]}, "b"]}
                   ]}
                ]},
               {:call, [{__MODULE__, :call}, {:access, [:key1]}]}
             ]},
            {:and,
             [
               {:and,
                [
                  {:==,
                   [
                     {:and, [{:is_map, [{:access, []}]}, {:==, [{:access, [:__struct__]}, A]}]},
                     false
                   ]},
                  {:and,
                   [
                     {:==,
                      [
                        {:and,
                         [
                           {:and,
                            [{:is_map, [{:access, []}]}, {:==, [{:access, [:__struct__]}, B]}]},
                           {:==, [{:access, [:key2]}, "b"]}
                         ]},
                        false
                      ]},
                     {:and, [{:is_map, [{:access, []}]}, {:==, [{:access, [:__struct__]}, C]}]}
                   ]}
                ]},
               {:call, [{__MODULE__, :call}, {:access, [:key1]}]}
             ]}
          ]}
       ]}

    assert expected == filter.code
  end

  test "support when guard" do
    filter =
      Filter.new(fn
        %A{key1: a, key2: b} when is_nil(a) and not is_nil(b) -> "a"
        %A{key1: a} when a in [:a, :b, :c] -> "b"
      end)

    expected =
      {:or,
       [
         {:and,
          [
            {:and,
             [
               {:and, [{:is_map, [{:access, []}]}, {:==, [{:access, [:__struct__]}, A]}]},
               {:and,
                [
                  {:is_nil, [{:access, [:key1]}]},
                  {:not, [{:is_nil, [{:access, [:key2]}]}]}
                ]}
             ]},
            "a"
          ]},
         {:and,
          [
            {:and,
             [
               {:==,
                [
                  {:and,
                   [
                     {:and, [{:is_map, [{:access, []}]}, {:==, [{:access, [:__struct__]}, A]}]},
                     {:and,
                      [
                        {:is_nil, [{:access, [:key1]}]},
                        {:not, [{:is_nil, [{:access, [:key2]}]}]}
                      ]}
                   ]},
                  false
                ]},
               {:and,
                [
                  {:and, [{:is_map, [{:access, []}]}, {:==, [{:access, [:__struct__]}, A]}]},
                  {:in, [{:access, [:key1]}, [:a, :b, :c]]}
                ]}
             ]},
            "b"
          ]}
       ]}

    assert expected == filter.code
  end
end
