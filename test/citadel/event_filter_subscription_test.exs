defmodule Citadel.EventFilterSubscriptionTest do
  use ExUnit.Case

  alias Citadel.Event
  alias Citadel.EventFilter
  alias Citadel.EventFilterSubscription
  alias Citadel.SagaID

  defmodule(TestEvent, do: defstruct([:value]))

  describe "match?/2" do
    test "matches without conditions" do
      assert EventFilterSubscription.match?(
               %EventFilterSubscription{
                 subscriber_saga_id: SagaID.new(),
                 event_filter: %EventFilter{}
               },
               Event.new(%TestEvent{value: true})
             )
    end

    test "checks event_filter" do
      assert EventFilterSubscription.match?(
               %EventFilterSubscription{
                 subscriber_saga_id: SagaID.new(),
                 event_filter: %EventFilter{
                   event_type: TestEvent
                 }
               },
               Event.new(%TestEvent{value: true})
             )

      refute EventFilterSubscription.match?(
               %EventFilterSubscription{
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
