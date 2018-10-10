defmodule Cizen.EventBodyFilterTest do
  use ExUnit.Case

  defmodule TestEvent do
    defstruct [:some_key]

    import Cizen.EventBodyFilter
    defeventbodyfilter(SomeKeyFilter, :some_key)

    defeventbodyfilter(WithBlock, :some_key) do
      def some_function, do: :defined
    end
  end

  defp setup_filter(_context) do
    %{filter: %TestEvent.SomeKeyFilter{value: :a}}
  end

  describe "EventBodyFilter.defeventbodyfilter" do
    setup [:setup_filter]

    alias Cizen.EventBodyFilter

    test "matches", %{filter: filter} do
      assert EventBodyFilter.test(filter, %TestEvent{some_key: :a})
    end

    test "does not matches", %{filter: filter} do
      refute EventBodyFilter.test(filter, %TestEvent{some_key: :b})
    end

    test "uses the do block" do
      alias TestEvent.WithBlock
      assert :defined == WithBlock.some_function()
    end
  end
end
