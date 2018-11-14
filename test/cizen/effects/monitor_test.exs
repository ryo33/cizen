defmodule Cizen.Effects.MonitorTest do
  use Cizen.SagaCase
  alias Cizen.Test
  alias Cizen.TestHelper

  alias Cizen.Effects.{Monitor, Receive}
  alias Cizen.Event
  alias Cizen.Filter
  alias Cizen.MonitorSaga

  defmodule(TestEvent, do: defstruct([:value]))

  describe "Monitor" do
    test "starts monitor" do
      assert_handle(fn id ->
        saga_id = TestHelper.launch_test_saga()

        perform(id, %Monitor{saga_id: saga_id})

        Test.ensure_finished(saga_id)

        event =
          perform(id, %Receive{
            event_filter:
              Filter.new(fn %Event{body: %MonitorSaga.Down{target_saga_id: value}} ->
                value == saga_id
              end)
          })

        assert %Event{body: %MonitorSaga.Down{target_saga_id: ^saga_id}} = event
      end)
    end

    test "returns an event filter for MonitorSaga.Down event" do
      assert_handle(fn id ->
        saga_id = TestHelper.launch_test_saga()

        event_filter = perform(id, %Monitor{saga_id: saga_id})

        assert event_filter ==
                 Filter.new(fn %Event{body: %MonitorSaga.Down{target_saga_id: value}} ->
                   value == saga_id
                 end)

        Test.ensure_finished(saga_id)

        event =
          perform(id, %Receive{
            event_filter: event_filter
          })

        assert %Event{body: %MonitorSaga.Down{target_saga_id: ^saga_id}} = event
      end)
    end
  end
end
