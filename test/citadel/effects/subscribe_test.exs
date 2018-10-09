defmodule Citadel.Effects.SubscribeTest do
  use Citadel.SagaCase

  alias Citadel.Automaton
  alias Citadel.Dispatcher
  alias Citadel.Effects.{Receive, Subscribe}
  alias Citadel.Event
  alias Citadel.EventFilter
  alias Citadel.SagaID

  alias Citadel.StartSaga

  defmodule(TestEvent, do: defstruct([:value]))

  describe "Subscribe" do
    defmodule TestAutomaton do
      use Automaton

      defstruct [:pid]

      @impl true
      def yield(id, %__MODULE__{pid: pid}) do
        send(
          pid,
          perform(id, %Subscribe{
            event_filter: EventFilter.new(event_type: TestEvent)
          })
        )

        send(
          pid,
          perform(id, %Receive{
            event_filter: EventFilter.new(event_type: TestEvent)
          })
        )

        Automaton.finish()
      end
    end

    test "transforms the result" do
      saga_id = SagaID.new()

      Dispatcher.dispatch(
        Event.new(%StartSaga{
          id: saga_id,
          saga: %TestAutomaton{pid: self()}
        })
      )

      assert_receive :ok
      event = Event.new(%TestEvent{value: :a})
      Dispatcher.dispatch(event)
      assert_receive ^event
    end
  end
end