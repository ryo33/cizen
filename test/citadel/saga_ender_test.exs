defmodule Citadel.SagaEnderTest do
  use ExUnit.Case
  alias Citadel.TestHelper

  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.Saga

  alias Citadel.EndSaga

  describe "SagaEnder" do
    test "dispatches Saga.Finish event on EndSaga event" do
      Dispatcher.listen_event_type(Saga.Finish)

      saga_id = TestHelper.launch_test_saga()

      Dispatcher.dispatch(
        Event.new(%EndSaga{
          id: saga_id
        })
      )

      assert_receive %Event{
        body: %Saga.Finish{id: ^saga_id}
      }
    end
  end
end
