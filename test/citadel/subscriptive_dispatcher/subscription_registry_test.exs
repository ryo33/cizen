defmodule Citadel.SubscriptiveDispatcher.SubscriptionRegistryTest do
  use ExUnit.Case

  import Citadel.TestHelper,
    only: [
      launch_test_saga: 0,
      ensure_finished: 1,
      assert_condition: 2
    ]

  alias Citadel.Event
  alias Citadel.Filter
  alias Citadel.Subscribe
  alias Citadel.Subscribed
  alias Citadel.Subscription
  alias Citadel.SubscriptiveDispatcher.SubscriptionRegistry
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

  test "FilterSetSubscribe event" do
    listen_event_type(Subscribed)
    saga_id = launch_test_saga()

    subscription = %Subscription{
      subscriber_saga_id: saga_id
    }

    dispatch(
      Event.new(%Subscribe{
        subscription: subscription
      })
    )

    assert_condition(
      100,
      SubscriptionRegistry.subscriptions() == [subscription]
    )

    assert_receive %Event{body: %Subscribed{subscription: subscription}}
  end

  test "remove subscription when the saga finishes" do
    saga_id = launch_test_saga()

    subscription = %Subscription{
      subscriber_saga_id: saga_id
    }

    dispatch(
      Event.new(%Subscribe{
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
