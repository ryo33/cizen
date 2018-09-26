defmodule Citadel.SubscriptionRegistryTest do
  use ExUnit.Case

  import Citadel.TestHelper,
    only: [
      launch_test_saga: 0,
      ensure_finished: 1,
      assert_condition: 2
    ]

  alias Citadel.Event
  alias Citadel.Filter
  alias Citadel.FilterSet
  alias Citadel.Subscribe
  alias Citadel.Subscribed
  alias Citadel.Subscription
  alias Citadel.SubscriptionRegistry
  import Citadel.Dispatcher, only: [dispatch: 1, listen_event_type: 1]

  defmodule TestFilterA do
    @behaviour Filter
    @impl true
    def test(_, _), do: false
  end

  defmodule TestFilterB do
    @behaviour Filter
    @impl true
    def test(_, _), do: false
  end

  test "Subscribe event" do
    listen_event_type(Subscribed)
    saga_id = launch_test_saga()
    filter_set = FilterSet.new([Filter.new(TestFilterA, :a), Filter.new(TestFilterB, :b)])

    dispatch(
      Event.new(%Subscribe{
        saga_id: saga_id,
        filter_set: filter_set
      })
    )

    assert_condition(
      100,
      SubscriptionRegistry.subscriptions() == [
        Subscription.new(saga_id, filter_set)
      ]
    )

    assert_receive %Event{body: %Subscribed{saga_id: ^saga_id, filter_set: ^filter_set}}
  end

  test "remove subscription when the saga finishes" do
    saga_id = launch_test_saga()
    filter_set = FilterSet.new([Filter.new(TestFilterA, :a), Filter.new(TestFilterB, :b)])

    dispatch(
      Event.new(%Subscribe{
        saga_id: saga_id,
        filter_set: filter_set
      })
    )

    assert_condition(
      100,
      SubscriptionRegistry.subscriptions() == [
        Subscription.new(saga_id, filter_set)
      ]
    )

    ensure_finished(saga_id)

    assert_condition(100, SubscriptionRegistry.subscriptions() == [])
  end
end
