defmodule Citadel.Effects.StartTest do
  use ExUnit.Case
  alias Citadel.TestHelper
  alias Citadel.TestSaga

  alias Citadel.Automaton
  alias Citadel.Dispatcher
  alias Citadel.Effects.Start
  alias Citadel.Event
  alias Citadel.Saga
  alias Citadel.SagaID

  alias Citadel.StartSaga

  defmodule(TestEvent, do: defstruct([:value]))

  describe "Start" do
    defmodule TestAutomaton do
      use Automaton

      defstruct [:pid]

      @impl true
      def yield(id, %__MODULE__{pid: pid}) do
        send(
          pid,
          perform(id, %Start{
            saga: %TestSaga{
              launch: fn id, _ -> send(pid, {:saga_id, id}) end
            }
          })
        )

        Automaton.finish()
      end
    end

    test "transforms the result" do
      saga_id = SagaID.new()
      Dispatcher.listen_event_body(%Saga.Finish{id: saga_id})

      Dispatcher.dispatch(
        Event.new(%StartSaga{
          id: saga_id,
          saga: %TestAutomaton{pid: self()}
        })
      )

      {_, sub_saga_id} = assert_receive {:saga_id, id}
      assert_receive ^sub_saga_id

      assert_receive %Event{body: %Saga.Finish{id: ^saga_id}}

      TestHelper.ensure_finished(saga_id)
      TestHelper.ensure_finished(sub_saga_id)
    end
  end
end
