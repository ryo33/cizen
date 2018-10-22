defmodule Cizen.SagaEnderTest do
  use Cizen.SagaCase
  alias Cizen.TestHelper

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.Saga

  alias Cizen.EndSaga

  describe "SagaEnder" do
    test "dispatches Saga.Finish event on EndSaga event" do
      Dispatcher.listen_event_type(Saga.Finish)

      saga_id = TestHelper.launch_test_saga()

      Dispatcher.dispatch(
        Event.new(nil, %EndSaga{
          id: saga_id
        })
      )

      assert_receive %Event{
        body: %Saga.Finish{id: ^saga_id}
      }
    end
  end
end
