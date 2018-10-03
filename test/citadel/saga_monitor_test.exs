defmodule Citadel.SagaMonitorTest do
  use ExUnit.Case
  alias Citadel.TestHelper
  import Citadel.TestHelper, only: [assert_condition: 2]

  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.Saga
  alias Citadel.SagaID
  alias Citadel.SagaMonitor

  alias Citadel.MonitorSaga

  describe "SagaMonitor" do
    test "does not finishes until the target saga finishes" do
      target_id = TestHelper.launch_test_saga()

      Dispatcher.dispatch(Event.new(%MonitorSaga{saga_id: target_id}))

      Dispatcher.listen_event_body(%MonitorSaga.Down{saga_id: target_id})

      refute_receive %Event{body: %MonitorSaga.Down{saga_id: ^target_id}}
    end

    test "finishes when the target saga finishes" do
      target_id = TestHelper.launch_test_saga()

      Dispatcher.dispatch(Event.new(%MonitorSaga{saga_id: target_id}))

      Dispatcher.listen_event_body(%MonitorSaga.Down{saga_id: target_id})

      Dispatcher.dispatch(Event.new(%Saga.Finish{id: target_id}))

      assert_receive %Event{body: %MonitorSaga.Down{saga_id: ^target_id}}
    end

    test "finishes when the target saga doesn't exists" do
      target_id = SagaID.new()

      Dispatcher.listen_event_body(%MonitorSaga.Down{saga_id: target_id})

      Dispatcher.dispatch(Event.new(%MonitorSaga{saga_id: target_id}))

      assert_receive %Event{body: %MonitorSaga.Down{saga_id: ^target_id}}
    end

    test "monitors once for multiple MonitorEvent" do
      target_id = TestHelper.launch_test_saga()

      Dispatcher.dispatch(Event.new(%MonitorSaga{saga_id: target_id}))
      Dispatcher.dispatch(Event.new(%MonitorSaga{saga_id: target_id}))
      Dispatcher.dispatch(Event.new(%MonitorSaga{saga_id: target_id}))

      Dispatcher.listen_event_body(%MonitorSaga.Down{saga_id: target_id})

      Dispatcher.dispatch(Event.new(%Saga.Finish{id: target_id}))

      assert_receive %Event{body: %MonitorSaga.Down{saga_id: ^target_id}}
      refute_receive %Event{body: %MonitorSaga.Down{}}
    end

    test "removes the monitors after down" do
      target_id = TestHelper.launch_test_saga()

      Dispatcher.dispatch(Event.new(%MonitorSaga{saga_id: target_id}))

      Dispatcher.listen_event_body(%MonitorSaga.Down{saga_id: target_id})

      Dispatcher.dispatch(Event.new(%Saga.Finish{id: target_id}))

      assert_receive %Event{body: %MonitorSaga.Down{saga_id: ^target_id}}

      assert_condition(
        100,
        :sys.get_state(SagaMonitor) == %{
          refs: %{},
          sagas: MapSet.new([])
        }
      )
    end
  end
end
