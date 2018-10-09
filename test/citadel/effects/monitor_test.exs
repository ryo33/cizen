defmodule Citadel.Effects.MonitorTest do
  use Citadel.SagaCase
  alias Citadel.TestHelper

  alias Citadel.Effects.{Monitor, Receive}
  alias Citadel.Event
  alias Citadel.EventFilter
  alias Citadel.MonitorSaga

  defmodule(TestEvent, do: defstruct([:value]))

  describe "Monitor" do
    test "starts monitor" do
      assert_handle(fn id ->
        saga_id = TestHelper.launch_test_saga()

        perform(id, %Monitor{saga_id: saga_id})

        TestHelper.ensure_finished(saga_id)

        event =
          perform(id, %Receive{
            event_filter: EventFilter.new()
          })

        assert %Event{body: %MonitorSaga.Down{target_saga_id: ^saga_id}} = event
      end)
    end

    test "returns an event filter for MonitorSaga.Down event" do
      assert_handle(fn id ->
        saga_id = TestHelper.launch_test_saga()

        event_filter = perform(id, %Monitor{saga_id: saga_id})

        assert event_filter ==
                 EventFilter.new(
                   event_type: MonitorSaga.Down,
                   event_body_filters: [
                     %MonitorSaga.Down.TargetSagaIDFilter{value: saga_id}
                   ]
                 )

        TestHelper.ensure_finished(saga_id)

        event =
          perform(id, %Receive{
            event_filter: event_filter
          })

        assert %Event{body: %MonitorSaga.Down{target_saga_id: ^saga_id}} = event
      end)
    end
  end
end
