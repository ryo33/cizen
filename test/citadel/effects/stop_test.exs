defmodule Cizen.Effects.EndTest do
  use Cizen.SagaCase
  alias Cizen.TestHelper

  alias Cizen.Effects.{End, Monitor, Receive}

  defmodule(TestEvent, do: defstruct([:value]))

  describe "End" do
    test "starts monitor" do
      assert_handle(fn id ->
        saga_id = TestHelper.launch_test_saga()

        down_filter = perform(id, %Monitor{saga_id: saga_id})

        assert saga_id == perform(id, %End{saga_id: saga_id})

        perform(id, %Receive{event_filter: down_filter})
      end)
    end
  end
end
