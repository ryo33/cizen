defmodule Cizen.DefaultEventRouterTest do
  use ExUnit.Case

  alias Cizen.DefaultEventRouter
  alias Cizen.Event
  alias Cizen.Filter
  require Filter

  defmodule(TestEventA, do: defstruct([]))
  defmodule(TestEventB, do: defstruct([]))
  defmodule(TestEventC, do: defstruct([]))

  defp put(filter, ref) do
    DefaultEventRouter.put(filter, ref)

    on_exit(fn ->
      DefaultEventRouter.delete(filter, ref)
    end)
  end

  test "returns empty routes for no subscriptions" do
    assert [] == DefaultEventRouter.routes(Event.new(nil, %TestEventA{}))
  end

  test "returns matched routes" do
    put(Filter.new(fn %Event{body: %TestEventA{}} -> true end), 1)
    put(Filter.new(fn %Event{body: %TestEventB{}} -> true end), 2)
    assert [1] == DefaultEventRouter.routes(Event.new(nil, %TestEventA{}))
    assert [2] == DefaultEventRouter.routes(Event.new(nil, %TestEventB{}))
    assert [] == DefaultEventRouter.routes(Event.new(nil, %TestEventC{}))
  end

  test "returns multiple matched routes" do
    put(Filter.new(fn %Event{body: %TestEventA{}} -> true end), 1)
    put(Filter.new(fn %Event{body: %TestEventA{}} -> true end), 2)
    put(Filter.new(fn %Event{body: %TestEventB{}} -> true end), 3)
    routes = DefaultEventRouter.routes(Event.new(nil, %TestEventA{}))
    assert MapSet.new([1, 2]) == MapSet.new(routes)
  end

  test "deletes subscription" do
    filter_1 = Filter.new(fn %Event{body: %TestEventA{}} -> true end)
    filter_2 = Filter.new(fn %Event{body: %TestEventA{}} -> true end)
    filter_3 = Filter.new(fn %Event{body: %TestEventB{}} -> true end)
    put(filter_1, 1)
    put(filter_2, 2)
    put(filter_3, 3)
    DefaultEventRouter.delete(filter_2, 2)
    DefaultEventRouter.delete(filter_3, 3)
    assert [1] == DefaultEventRouter.routes(Event.new(nil, %TestEventA{}))
    assert [] == DefaultEventRouter.routes(Event.new(nil, %TestEventB{}))
  end
end
