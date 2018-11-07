defmodule Cizen.Performance.DefaultEventRouterTest do
  use ExUnit.Case

  alias Cizen.DefaultEventRouter, as: Router
  alias Cizen.Event
  alias Cizen.Filter
  require Filter

  defmodule(TestEvent, do: defstruct([:value]))

  @tag timeout: 500
  test "10000 events with 10000 subscription" do
    subscriptions =
      0..99
      |> Stream.cycle()
      |> Stream.map(fn num ->
        Filter.new(fn %Event{body: %TestEvent{value: ^num}} -> true end)
      end)
      |> Stream.map(fn filter ->
        ref = make_ref()
        Router.put(filter, ref)
        {filter, ref}
      end)
      |> Enum.take(10_000)

    0..99
    |> Stream.cycle()
    |> Stream.each(fn num ->
      routes = Router.routes(Event.new(nil, %TestEvent{value: num}))
      assert length(routes) == 100
    end)
    |> Enum.take(10_000)

    Enum.each(subscriptions, fn {filter, ref} ->
      Router.delete(filter, ref)
    end)
  end
end
