defmodule Cizen.EventTest do
  use Cizen.SagaCase

  alias Cizen.Event

  defmodule(TestEvent, do: defstruct([:value]))

  defmodule TestSaga do
    defstruct [:value]
    def init(_id, saga), do: saga
    def handle_event(_id, _event, state), do: state
  end

  describe "new/2" do
    test "returns an event" do
      saga = %TestSaga{value: :some_value}

      saga_id =
        handle fn id ->
          perform id, %Start{saga: saga}
        end

      body = %TestEvent{value: :a}
      event = Event.new(saga_id, body)

      assert %Event{
               body: ^body,
               source_saga_id: ^saga_id,
               source_saga: ^saga
             } = event
    end

    test "returns an event with a unique event ID" do
      saga_id =
        handle fn id ->
          perform id, %Start{saga: %TestSaga{value: :some_value}}
        end

      event1 = Event.new(saga_id, %TestEvent{value: :a})
      event2 = Event.new(saga_id, %TestEvent{value: :a})
      assert event1 != event2
      assert event1.id != event2.id
    end

    test "returns an event with no saga ID" do
      body = %TestEvent{value: :a}
      event = Event.new(nil, body)

      assert %Event{
               body: ^body,
               source_saga_id: nil,
               source_saga: nil
             } = event
    end
  end
end
