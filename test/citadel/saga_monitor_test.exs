defmodule Citadel.SagaMonitorTest do
  use ExUnit.Case
  alias Citadel.TestHelper

  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.Saga
  alias Citadel.SagaID
  alias Citadel.SagaLauncher
  alias Citadel.SagaMonitor

  describe "SagaMonitor" do
    test "does not finishes until the target saga finishes" do
      target_id = TestHelper.launch_test_saga()

      monitor_id = SagaLauncher.launch_saga(%SagaMonitor{target_saga_id: target_id})

      Dispatcher.listen_event_body(%Saga.Finished{id: monitor_id})

      refute_receive %Saga.Finished{id: ^monitor_id}
    end

    test "finishes when the target saga finishes" do
      target_id = TestHelper.launch_test_saga()

      monitor_id = SagaLauncher.launch_saga(%SagaMonitor{target_saga_id: target_id})

      Dispatcher.listen_event_body(%Saga.Finished{id: monitor_id})

      Dispatcher.dispatch(Event.new(%Saga.Finish{id: target_id}))

      assert_receive %Event{body: %Saga.Finished{id: ^monitor_id}}
    end

    test "finishes when the target saga doesn't exists" do
      target_id = SagaID.new()

      Dispatcher.listen_event_type(Saga.Finished)

      monitor_id = SagaLauncher.launch_saga(%SagaMonitor{target_saga_id: target_id})

      assert_receive %Event{body: %Saga.Finished{id: ^monitor_id}}
    end
  end
end
