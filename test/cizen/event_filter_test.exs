defmodule Cizen.EventFilterTest do
  use ExUnit.Case

  alias Cizen.Event
  alias Cizen.EventBodyFilter
  alias Cizen.EventBodyFilterSet
  alias Cizen.EventFilter
  alias Cizen.SagaID

  defmodule(TestEvent, do: defstruct([:value_a, :value_b]))

  defmodule TestEventBodyFilterA do
    @behaviour EventBodyFilter
    defstruct [:value]
    @impl true
    def test(%__MODULE__{value: value}, %TestEvent{value_a: value}), do: true
    def test(_, _), do: false
  end

  defmodule TestEventBodyFilterB do
    @behaviour EventBodyFilter
    defstruct [:value]
    @impl true
    def test(%__MODULE__{value: value}, %TestEvent{value_b: value}), do: true
    def test(_, _), do: false
  end

  describe "test/2" do
    test "matches when all parameters are matched" do
      saga_id = SagaID.new()

      assert EventFilter.test(
               %EventFilter{
                 event_type: TestEvent,
                 source_saga_id: saga_id,
                 event_body_filter_set:
                   EventBodyFilterSet.new([
                     %TestEventBodyFilterA{value: :a},
                     %TestEventBodyFilterB{value: :b}
                   ])
               },
               Event.new(saga_id, %TestEvent{value_a: :a, value_b: :b})
             )
    end

    test "matches when all parameters are nil" do
      assert EventFilter.test(
               %EventFilter{},
               Event.new(nil, %TestEvent{})
             )
    end

    test "checks source saga ID" do
      saga_id = SagaID.new()

      assert EventFilter.test(
               %EventFilter{source_saga_id: saga_id},
               Event.new(saga_id, %TestEvent{})
             )

      refute EventFilter.test(
               %EventFilter{source_saga_id: saga_id},
               Event.new(SagaID.new(), %TestEvent{})
             )
    end

    test "checks event type" do
      assert EventFilter.test(
               %EventFilter{event_type: TestEvent},
               Event.new(nil, %TestEvent{})
             )

      refute EventFilter.test(
               %EventFilter{event_type: UnknownEvent},
               Event.new(nil, %TestEvent{})
             )
    end

    test "checks with using event body filter set" do
      assert EventFilter.test(
               %EventFilter{
                 event_type: TestEvent,
                 event_body_filter_set:
                   EventBodyFilterSet.new([
                     %TestEventBodyFilterA{value: :a},
                     %TestEventBodyFilterB{value: :b}
                   ])
               },
               Event.new(nil, %TestEvent{value_a: :a, value_b: :b})
             )

      refute EventFilter.test(
               %EventFilter{
                 event_type: TestEvent,
                 event_body_filter_set:
                   EventBodyFilterSet.new([
                     %TestEventBodyFilterA{value: :a},
                     %TestEventBodyFilterB{value: :b}
                   ])
               },
               Event.new(nil, %TestEvent{value_a: :c, value_b: :c})
             )
    end
  end

  describe "new/1" do
    test "works with all parameters" do
      event_type = TestEvent
      saga_id = SagaID.new()
      require EventFilter

      actual =
        EventFilter.new(
          event_type: event_type,
          source_saga_id: saga_id,
          event_body_filters: [
            %TestEventBodyFilterA{value: :a},
            %TestEventBodyFilterB{value: :b}
          ]
        )

      expected = %EventFilter{
        event_type: event_type,
        source_saga_id: saga_id,
        event_body_filter_set:
          EventBodyFilterSet.new([
            %TestEventBodyFilterA{value: :a},
            %TestEventBodyFilterB{value: :b}
          ])
      }

      assert actual == expected
    end

    test "works with some lacks of parameters" do
      event_type = TestEvent
      require EventFilter
      actual = EventFilter.new(event_type: event_type)

      expected = %EventFilter{
        event_type: event_type,
        source_saga_id: nil,
        event_body_filter_set: EventBodyFilterSet.new([])
      }

      assert actual == expected
    end

    test "works with no arguments" do
      require EventFilter
      actual = EventFilter.new()

      expected = %EventFilter{
        event_type: nil,
        source_saga_id: nil,
        event_body_filter_set: EventBodyFilterSet.new([])
      }

      assert actual == expected
    end

    test "compile error for unknown params" do
      assert_raise ArgumentError, fn ->
        Code.compile_quoted(
          quote do
            require EventFilter

            EventFilter.new(
              event_type: TestEvent,
              unknown_key: :unknown
            )
          end
        )
      end
    end

    test "compile error for unknown event type" do
      assert_raise ArgumentError, fn ->
        Code.compile_quoted(
          quote do
            require EventFilter

            EventFilter.new(event_type: UnknownEvent)
          end
        )
      end
    end
  end
end
