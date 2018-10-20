defmodule Cizen.SagaMonitorTest do
  use Cizen.SagaCase
  alias Cizen.TestHelper
  import Cizen.TestHelper, only: [assert_condition: 2]

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.Saga
  alias Cizen.SagaID
  alias Cizen.SagaMonitor

  alias Cizen.MonitorSaga

  describe "SagaMonitor" do
    test "does not dispatches Down until the target saga finishes" do
      pid = self()

      monitor_id =
        TestHelper.launch_test_saga(
          handle_event: fn _id, event, _state ->
            send(pid, event)
          end
        )

      target_id = TestHelper.launch_test_saga()

      Dispatcher.dispatch(
        Event.new(%MonitorSaga{monitor_saga_id: monitor_id, target_saga_id: target_id})
      )

      refute_receive %Event{
        body: %MonitorSaga.Down{monitor_saga_id: ^monitor_id, target_saga_id: ^target_id}
      }
    end

    test "dispatches Down when the target saga finishes" do
      pid = self()

      monitor_id =
        TestHelper.launch_test_saga(
          handle_event: fn _id, event, _state ->
            send(pid, event)
          end
        )

      target_id = TestHelper.launch_test_saga()

      Dispatcher.dispatch(
        Event.new(%MonitorSaga{monitor_saga_id: monitor_id, target_saga_id: target_id})
      )

      Dispatcher.dispatch(Event.new(%Saga.Finish{id: target_id}))

      assert_receive %Event{
        body: %MonitorSaga.Down{monitor_saga_id: ^monitor_id, target_saga_id: ^target_id}
      }
    end

    test "dispatches Down for multiple monitors" do
      pid = self()

      monitor_a =
        TestHelper.launch_test_saga(
          handle_event: fn _id, event, _state ->
            send(pid, {:a, event})
          end
        )

      monitor_b =
        TestHelper.launch_test_saga(
          handle_event: fn _id, event, _state ->
            send(pid, {:b, event})
          end
        )

      target_id = TestHelper.launch_test_saga()

      Dispatcher.dispatch(
        Event.new(%MonitorSaga{monitor_saga_id: monitor_a, target_saga_id: target_id})
      )

      Dispatcher.dispatch(
        Event.new(%MonitorSaga{monitor_saga_id: monitor_b, target_saga_id: target_id})
      )

      Dispatcher.dispatch(Event.new(%Saga.Finish{id: target_id}))

      assert_receive {:a,
                      %Event{
                        body: %MonitorSaga.Down{
                          monitor_saga_id: ^monitor_a,
                          target_saga_id: ^target_id
                        }
                      }}

      assert_receive {:b,
                      %Event{
                        body: %MonitorSaga.Down{
                          monitor_saga_id: ^monitor_b,
                          target_saga_id: ^target_id
                        }
                      }}
    end

    test "dispatches Down when the target saga doesn't exists" do
      pid = self()

      monitor_id =
        TestHelper.launch_test_saga(
          handle_event: fn _id, event, _state ->
            send(pid, event)
          end
        )

      target_id = SagaID.new()

      Dispatcher.dispatch(
        Event.new(%MonitorSaga{monitor_saga_id: monitor_id, target_saga_id: target_id})
      )

      assert_receive %Event{
        body: %MonitorSaga.Down{monitor_saga_id: ^monitor_id, target_saga_id: ^target_id}
      }
    end

    test "monitors once for multiple MonitorEvent" do
      pid = self()

      monitor_id =
        TestHelper.launch_test_saga(
          handle_event: fn _id, event, _state ->
            send(pid, event)
          end
        )

      target_id = TestHelper.launch_test_saga()

      Dispatcher.dispatch(
        Event.new(%MonitorSaga{monitor_saga_id: monitor_id, target_saga_id: target_id})
      )

      Dispatcher.dispatch(
        Event.new(%MonitorSaga{monitor_saga_id: monitor_id, target_saga_id: target_id})
      )

      Dispatcher.dispatch(
        Event.new(%MonitorSaga{monitor_saga_id: monitor_id, target_saga_id: target_id})
      )

      Dispatcher.dispatch(Event.new(%Saga.Finish{id: target_id}))

      assert_receive %Event{
        body: %MonitorSaga.Down{monitor_saga_id: ^monitor_id, target_saga_id: ^target_id}
      }

      refute_receive %Event{body: %MonitorSaga.Down{}}
    end

    test "removes the monitors after down" do
      old_state = :sys.get_state(SagaMonitor)
      pid = self()

      monitor_id =
        TestHelper.launch_test_saga(
          handle_event: fn _id, event, _state ->
            send(pid, event)
          end
        )

      target_id = TestHelper.launch_test_saga()

      Dispatcher.dispatch(
        Event.new(%MonitorSaga{monitor_saga_id: monitor_id, target_saga_id: target_id})
      )

      Dispatcher.dispatch(Event.new(%Saga.Finish{id: target_id}))

      assert_receive %Event{
        body: %MonitorSaga.Down{monitor_saga_id: ^monitor_id, target_saga_id: ^target_id}
      }

      assert_condition(
        100,
        :sys.get_state(SagaMonitor) == old_state
      )
    end
  end
end
