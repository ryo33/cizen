defmodule Citadel.SubscriptionTest do
  use ExUnit.Case

  alias Citadel.Event
  alias Citadel.FilterSet
  alias Citadel.SagaID
  alias Citadel.Subscription

  defmodule(TestEvent, do: defstruct([:value]))

  describe "match?/2" do
    test "matches without conditions" do
      assert Subscription.match?(
               %Subscription{subscriber_saga_id: SagaID.new()},
               Event.new(%TestEvent{value: true}, SagaID.new(), DummyModule)
             )
    end

    test "checks source_saga_id" do
      source_saga_id = SagaID.new()

      assert Subscription.match?(
               %Subscription{subscriber_saga_id: SagaID.new(), source_saga_id: source_saga_id},
               Event.new(%TestEvent{value: true}, source_saga_id, DummyModule)
             )

      refute Subscription.match?(
               %Subscription{subscriber_saga_id: SagaID.new(), source_saga_id: SagaID.new()},
               Event.new(%TestEvent{value: true}, source_saga_id, DummyModule)
             )
    end

    test "checks source_saga_module" do
      assert Subscription.match?(
               %Subscription{subscriber_saga_id: SagaID.new(), source_saga_module: DummyModule},
               Event.new(%TestEvent{value: true}, SagaID.new(), DummyModule)
             )

      refute Subscription.match?(
               %Subscription{
                 subscriber_saga_id: SagaID.new(),
                 source_saga_module: DifferentModule
               },
               Event.new(%TestEvent{value: true}, SagaID.new(), DummyModule)
             )
    end

    test "checks filter_set" do
      assert Subscription.match?(
               %Subscription{
                 subscriber_saga_id: SagaID.new(),
                 filter_set: FilterSet.new(TestEvent, [])
               },
               Event.new(%TestEvent{value: true}, SagaID.new(), DummyModule)
             )

      refute Subscription.match?(
               %Subscription{
                 subscriber_saga_id: SagaID.new(),
                 filter_set: FilterSet.new(UnknownEvent, [])
               },
               Event.new(%TestEvent{value: true}, SagaID.new(), DummyModule)
             )
    end
  end
end
