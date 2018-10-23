defmodule Cizen.EventFilterTest do
  use Cizen.SagaCase

  alias Cizen.Event
  alias Cizen.EventBodyFilter
  alias Cizen.EventBodyFilterSet
  alias Cizen.EventFilter
  alias Cizen.SagaFilter
  alias Cizen.SagaFilterSet
  alias Cizen.SagaID

  defmodule(TestEvent, do: defstruct([:value_a, :value_b]))

  defmodule TestSaga do
    defstruct [:value_a, :value_b]
    def init(_id, saga), do: saga
    def handle_event(_id, _event, state), do: state
  end

  defmodule TestEventBodyFilterA do
    @behaviour EventBodyFilter
    defstruct [:value]
    @impl true
    def test(%__MODULE__{value: value}, %TestEvent{value_a: value}), do: true
    def test(_, %TestEvent{}), do: false
  end

  defmodule TestEventBodyFilterB do
    @behaviour EventBodyFilter
    defstruct [:value]
    @impl true
    def test(%__MODULE__{value: value}, %TestEvent{value_b: value}), do: true
    def test(_, %TestEvent{}), do: false
  end

  defmodule TestSagaFilterA do
    @behaviour SagaFilter
    defstruct [:value]
    @impl true
    def test(%__MODULE__{value: value}, %TestSaga{value_a: value}), do: true
    def test(_, %TestSaga{}), do: false
  end

  defmodule TestSagaFilterB do
    @behaviour SagaFilter
    defstruct [:value]
    @impl true
    def test(%__MODULE__{value: value}, %TestSaga{value_b: value}), do: true
    def test(_, %TestSaga{}), do: false
  end

  defp new_event_from(saga, body) do
    saga_id =
      handle fn id ->
        perform id, %Start{saga: saga}
      end

    Event.new(saga_id, body)
  end

  describe "test/2" do
    test "matches when all parameters are matched" do
      saga_id =
        handle fn id ->
          perform id, %Start{saga: %TestSaga{value_a: :a, value_b: :b}}
        end

      assert EventFilter.test(
               %EventFilter{
                 event_type: TestEvent,
                 source_saga_id: saga_id,
                 source_saga_module: TestSaga,
                 source_saga_filter_set:
                   SagaFilterSet.new([
                     %TestSagaFilterA{value: :a},
                     %TestSagaFilterB{value: :b}
                   ]),
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
               new_event_from(%TestSaga{}, %TestEvent{})
             )
    end

    test "checks source saga ID" do
      saga_id =
        handle fn id ->
          perform id, %Start{saga: %TestSaga{}}
        end

      assert EventFilter.test(
               %EventFilter{source_saga_id: saga_id},
               Event.new(saga_id, %TestEvent{})
             )

      refute EventFilter.test(
               %EventFilter{source_saga_id: SagaID.new()},
               Event.new(saga_id, %TestEvent{})
             )
    end

    test "checks event type" do
      assert EventFilter.test(
               %EventFilter{event_type: TestEvent},
               new_event_from(%TestSaga{}, %TestEvent{})
             )

      refute EventFilter.test(
               %EventFilter{event_type: UnknownEvent},
               new_event_from(%TestSaga{}, %TestEvent{})
             )
    end

    test "checks with using event body filter set" do
      assert EventFilter.test(
               %EventFilter{
                 event_body_filter_set:
                   EventBodyFilterSet.new([
                     %TestEventBodyFilterA{value: :a},
                     %TestEventBodyFilterB{value: :b}
                   ])
               },
               new_event_from(%TestSaga{}, %TestEvent{value_a: :a, value_b: :b})
             )

      refute EventFilter.test(
               %EventFilter{
                 event_body_filter_set:
                   EventBodyFilterSet.new([
                     %TestEventBodyFilterA{value: :a},
                     %TestEventBodyFilterB{value: :b}
                   ])
               },
               new_event_from(%TestSaga{}, %TestEvent{value_a: :c, value_b: :c})
             )
    end

    test "checks saga module" do
      assert EventFilter.test(
               %EventFilter{source_saga_module: TestSaga},
               new_event_from(%TestSaga{}, %TestEvent{})
             )

      refute EventFilter.test(
               %EventFilter{source_saga_module: UnknownSaga},
               new_event_from(%TestSaga{}, %TestEvent{})
             )

      refute EventFilter.test(
               %EventFilter{source_saga_module: TestSaga},
               Event.new(nil, %TestEvent{})
             )
    end

    test "checks with using saga filter set" do
      assert EventFilter.test(
               %EventFilter{
                 source_saga_filter_set:
                   SagaFilterSet.new([
                     %TestSagaFilterA{value: :a},
                     %TestSagaFilterB{value: :b}
                   ])
               },
               new_event_from(%TestSaga{value_a: :a, value_b: :b}, %TestEvent{})
             )

      refute EventFilter.test(
               %EventFilter{
                 source_saga_filter_set:
                   SagaFilterSet.new([
                     %TestSagaFilterA{value: :a},
                     %TestSagaFilterB{value: :b}
                   ])
               },
               new_event_from(%TestSaga{value_a: :c, value_b: :c}, %TestEvent{})
             )

      refute EventFilter.test(
               %EventFilter{
                 source_saga_filter_set:
                   SagaFilterSet.new([
                     %TestSagaFilterA{value: :a},
                     %TestSagaFilterB{value: :b}
                   ])
               },
               Event.new(nil, %TestEvent{})
             )
    end
  end

  describe "new/1" do
    test "works with all parameters" do
      event_type = TestEvent
      saga_id = SagaID.new()
      source_saga_module = TestSaga
      require EventFilter

      actual =
        EventFilter.new(
          event_type: event_type,
          source_saga_id: saga_id,
          source_saga_module: source_saga_module,
          source_saga_filters: [
            %TestSagaFilterA{value: :a},
            %TestSagaFilterB{value: :b}
          ],
          event_body_filters: [
            %TestEventBodyFilterA{value: :a},
            %TestEventBodyFilterB{value: :b}
          ]
        )

      expected = %EventFilter{
        event_type: event_type,
        source_saga_id: saga_id,
        source_saga_module: source_saga_module,
        source_saga_filter_set:
          SagaFilterSet.new([
            %TestSagaFilterA{value: :a},
            %TestSagaFilterB{value: :b}
          ]),
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
        source_saga_filter_set: nil,
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
        source_saga_module: nil,
        source_saga_filter_set: nil,
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

    test "compile error for unknown saga module" do
      assert_raise ArgumentError, fn ->
        Code.compile_quoted(
          quote do
            require EventFilter

            EventFilter.new(source_saga_module: UnknownSaga)
          end
        )
      end
    end
  end
end
