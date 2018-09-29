defmodule Citadel.EventFilterDispatcher.SubscriptionRegistryTest do
  use ExUnit.Case

  import Citadel.TestHelper,
    only: [
      launch_test_saga: 0,
      ensure_finished: 1,
      assert_condition: 2
    ]

  alias Citadel.Event
  alias Citadel.EventBodyFilter
  alias Citadel.EventFilter
  alias Citadel.EventFilterDispatcher.SubscriptionRegistry
  alias Citadel.EventFilterSubscribed
  alias Citadel.EventFilterSubscription
  alias Citadel.SubscribeEventFilter
  import Citadel.Dispatcher, only: [dispatch: 1, listen_event_type: 1]

  defmodule TestEventBodyFilterA do
    @behaviour EventBodyFilter
    @impl true
    def test(_, _), do: false
  end

  defmodule TestEventBodyFilterB do
    @behaviour EventBodyFilter
    @impl true
    def test(_, _), do: false
  end

  test "EventFilterSubscribe event" do
    assert_condition(100, SubscriptionRegistry.subscriptions() == [])

    listen_event_type(EventFilterSubscribed)
    saga_id = launch_test_saga()

    subscription = %EventFilterSubscription{
      subscriber_saga_id: saga_id,
      event_filter: %EventFilter{}
    }

    dispatch(
      Event.new(%SubscribeEventFilter{
        subscription: subscription
      })
    )

    assert_condition(
      100,
      SubscriptionRegistry.subscriptions() == [subscription]
    )

    assert_receive %Event{body: %EventFilterSubscribed{subscription: subscription}}
  end

  test "remove subscription when the saga finishes" do
    assert_condition(1000, SubscriptionRegistry.subscriptions() == [])

    saga_id = launch_test_saga()

    subscription = %EventFilterSubscription{
      subscriber_saga_id: saga_id,
      event_filter: %EventFilter{}
    }

    dispatch(
      Event.new(%SubscribeEventFilter{
        subscription: subscription
      })
    )

    assert_condition(
      100,
      SubscriptionRegistry.subscriptions() == [subscription]
    )

    ensure_finished(saga_id)

    assert_condition(100, SubscriptionRegistry.subscriptions() == [])
  end
end
