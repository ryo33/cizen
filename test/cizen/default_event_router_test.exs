defmodule Cizen.DefaultEventRouterTest do
  use ExUnit.Case

  alias Cizen.DefaultEventRouter
  alias Cizen.Event
  alias Cizen.EventFilter
  require EventFilter

  defmodule(TestEventA, do: defstruct([]))
  defmodule(TestEventB, do: defstruct([]))
  defmodule(TestEventC, do: defstruct([]))

  defp put(subscription) do
    DefaultEventRouter.put(subscription)

    on_exit(fn ->
      DefaultEventRouter.delete(subscription)
    end)
  end

  test "returns empty routes for no subscriptions" do
    assert [] == DefaultEventRouter.routes(Event.new(nil, %TestEventA{}))
  end

  test "returns matched routes" do
    subscription_a = {EventFilter.new(event_type: TestEventA), 1}
    subscription_b = {EventFilter.new(event_type: TestEventB), 2}
    put(subscription_a)
    put(subscription_b)
    assert [subscription_a] == DefaultEventRouter.routes(Event.new(nil, %TestEventA{}))
    assert [subscription_b] == DefaultEventRouter.routes(Event.new(nil, %TestEventB{}))
    assert [] == DefaultEventRouter.routes(Event.new(nil, %TestEventC{}))
  end

  test "returns multiple matched routes" do
    subscription_1 = {EventFilter.new(event_type: TestEventA), 1}
    subscription_2 = {EventFilter.new(event_type: TestEventA), 2}
    subscription_3 = {EventFilter.new(event_type: TestEventB), 3}
    put(subscription_1)
    put(subscription_2)
    put(subscription_3)
    routes = DefaultEventRouter.routes(Event.new(nil, %TestEventA{}))
    assert MapSet.new([subscription_1, subscription_2]) == MapSet.new(routes)
  end

  test "deletes subscription" do
    subscription_1 = {EventFilter.new(event_type: TestEventA), 1}
    subscription_2 = {EventFilter.new(event_type: TestEventA), 2}
    subscription_3 = {EventFilter.new(event_type: TestEventB), 3}
    put(subscription_1)
    put(subscription_2)
    put(subscription_3)
    DefaultEventRouter.delete(subscription_2)
    DefaultEventRouter.delete(subscription_3)
    assert [subscription_1] == DefaultEventRouter.routes(Event.new(nil, %TestEventA{}))
    assert [] == DefaultEventRouter.routes(Event.new(nil, %TestEventB{}))
  end
end
