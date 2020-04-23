defmodule Cizen.Effects.ResumeTest do
  use Cizen.SagaCase

  alias Cizen.SagaID
  alias Cizen.TestSaga

  alias Cizen.Effects.Resume

  describe "Resume" do
    test "resume a saga" do
      pid = self()
      saga_id = SagaID.new()
      state = :some_state

      assert ^saga_id =
               assert_handle(fn id ->
                 perform id, %Resume{
                   id: saga_id,
                   saga: %TestSaga{
                     resume: fn id, saga, state -> send(pid, {id, saga, state}) end,
                     extra: 42
                   },
                   state: state
                 }
               end)

      assert_receive {^saga_id, %TestSaga{extra: 42}, ^state}
    end
  end
end
