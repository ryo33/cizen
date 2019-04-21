defmodule Cizen.Effects.StartTest do
  use Cizen.SagaCase
  alias Cizen.TestSaga

  alias Cizen.Effects.Start

  defmodule(TestEvent, do: defstruct([:value]))

  describe "Start" do
    test "starts a saga" do
      pid = self()

      id =
        assert_handle(fn id ->
          perform id, %Start{
            saga: %TestSaga{
              init: fn id, _ -> send(pid, {:saga_id, id}) end
            }
          }
        end)

      assert_receive {:saga_id, ^id}
    end
  end
end
