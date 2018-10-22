defmodule Cizen.Effects.SubscribeTest do
  use Cizen.SagaCase

  alias Cizen.Automaton
  alias Cizen.Dispatcher
  alias Cizen.Effects.{Receive, Subscribe}
  alias Cizen.Event
  alias Cizen.EventFilter
  alias Cizen.SagaID

  alias Cizen.StartSaga

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

    test "subscribes messages" do
      saga_id = SagaID.new()

      Dispatcher.dispatch(
        Event.new(nil, %StartSaga{
          id: saga_id,
          saga: %TestAutomaton{pid: self()}
        })
      )

      assert_receive :ok
      event = Event.new(nil, %TestEvent{value: :a})
      Dispatcher.dispatch(event)
      assert_receive ^event
    end
  end
end
