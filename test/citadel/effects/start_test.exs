defmodule Cizen.Effects.StartTest do
  use Cizen.SagaCase
  alias Cizen.TestSaga

  alias Cizen.Automaton
  alias Cizen.Dispatcher
  alias Cizen.Effects.Start
  alias Cizen.Event
  alias Cizen.Saga
  alias Cizen.SagaID

  alias Cizen.StartSaga

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
    end
  end
end
