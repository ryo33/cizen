defmodule Citadel.EventFilterDispatcher.SubscriptionTest do
  use ExUnit.Case

  alias Citadel.Event
  alias Citadel.EventFilter
  alias Citadel.EventFilterDispatcher.Subscription
  alias Citadel.SagaID

  defmodule(TestEvent, do: defstruct([:value]))

  describe "match?/2" do
    test "matches without conditions" do
      assert Subscription.match?(
               %Subscription{
                 subscriber_saga_id: SagaID.new(),
                 event_filter: %EventFilter{}
               },
               Event.new(%TestEvent{value: true})
             )
    end

    test "checks event_filter" do
      assert Subscription.match?(
               %Subscription{
                 subscriber_saga_id: SagaID.new(),
                 event_filter: %EventFilter{
                   event_type: TestEvent
                 }
               },
               Event.new(%TestEvent{value: true})
             )

      refute Subscription.match?(
               %Subscription{
                 subscriber_saga_id: SagaID.new(),
                 event_filter: %EventFilter{
                   event_type: UnknownEvent
                 }
               },
               Event.new(%TestEvent{value: true})
             )
    end
  end
end
