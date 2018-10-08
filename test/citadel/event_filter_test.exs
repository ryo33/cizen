defmodule Citadel.EventFilterTest do
  use ExUnit.Case

  alias Citadel.Event
  alias Citadel.EventBodyFilter
  alias Citadel.EventBodyFilterSet
  alias Citadel.EventFilter
  alias Citadel.SagaID

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
      saga_module = TestSaga

      assert EventFilter.test(
               %EventFilter{
                 event_type: TestEvent,
                 source_saga_id: saga_id,
                 source_saga_module: saga_module,
                 event_body_filter_set:
                   EventBodyFilterSet.new([
                     %TestEventBodyFilterA{value: :a},
                     %TestEventBodyFilterB{value: :b}
                   ])
               },
               Event.new(%TestEvent{value_a: :a, value_b: :b}, saga_id, saga_module)
             )
    end

    test "matches when all parameters are nil" do
      assert EventFilter.test(
               %EventFilter{},
               Event.new(%TestEvent{})
             )
    end

    test "checks source saga ID" do
      saga_id = SagaID.new()

      assert EventFilter.test(
               %EventFilter{source_saga_id: saga_id},
               Event.new(%TestEvent{}, saga_id)
             )

      refute EventFilter.test(
               %EventFilter{source_saga_id: saga_id},
               Event.new(%TestEvent{}, SagaID.new())
             )
    end

    test "checks source saga module" do
      assert EventFilter.test(
               %EventFilter{source_saga_module: TestSaga},
               Event.new(%TestEvent{}, SagaID.new(), TestSaga)
             )

      refute EventFilter.test(
               %EventFilter{source_saga_module: TestSaga},
               Event.new(%TestEvent{}, SagaID.new(), UnknownSaga)
             )
    end

    test "checks event type" do
      assert EventFilter.test(
               %EventFilter{event_type: TestEvent},
               Event.new(%TestEvent{})
             )

      refute EventFilter.test(
               %EventFilter{event_type: UnknownEvent},
               Event.new(%TestEvent{})
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
               Event.new(%TestEvent{value_a: :a, value_b: :b})
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
               Event.new(%TestEvent{value_a: :c, value_b: :c})
             )
    end
  end

  describe "new/1" do
    test "works with all parameters" do
      event_type = TestEvent
      saga_id = SagaID.new()
      saga_module = TestSaga
      require EventFilter

      actual =
        EventFilter.new(
          event_type: event_type,
          source_saga_id: saga_id,
          source_saga_module: saga_module,
          event_body_filters: [
            %TestEventBodyFilterA{value: :a},
            %TestEventBodyFilterB{value: :b}
          ]
        )

      expected = %EventFilter{
        event_type: event_type,
        source_saga_id: saga_id,
        source_saga_module: saga_module,
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
        source_saga_module: nil,
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
  end
end
