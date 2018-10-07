defmodule Citadel.Automaton.Effects.ReceiveTest do
  use ExUnit.Case
  alias Citadel.TestHelper

  alias Citadel.Automaton
  alias Citadel.Automaton.Effect
  alias Citadel.Automaton.Effects.Receive
  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.EventFilter
  alias Citadel.Messenger
  alias Citadel.Saga
  alias Citadel.SagaID

  alias Citadel.StartSaga

  defmodule(TestEvent1, do: defstruct([:value]))
  defmodule(TestEvent2, do: defstruct([:value]))

  defp setup_receive(_context) do
    id = SagaID.new()

    effect = %Receive{
      event_filter: %EventFilter{
        event_type: TestEvent1
      }
    }

    %{handler: id, effect: effect}
  end

  describe "Receive" do
    setup [:setup_receive]

    test "does not resolves on init", %{handler: id, effect: effect} do
      refute match?({:resolve, _}, Effect.init(id, effect))
    end

    test "resolves if matched", %{handler: id, effect: effect} do
      state = Effect.init(id, effect)

      event = Event.new(%TestEvent1{})
      assert {:resolve, ^event} = Effect.handle_event(id, event, effect, state)
    end

    test "does not resolve if not matched", %{handler: id, effect: effect} do
      state = Effect.init(id, effect)

      refute match?(
               {:resolve, _},
               Effect.handle_event(id, Event.new(%TestEvent2{}), effect, state)
             )
    end

    defmodule TestAutomaton do
      use Automaton

      defstruct [:pid]

      @impl true
      def yield(id, %__MODULE__{pid: pid}) do
        test_event1_filter = %EventFilter{
          event_type: TestEvent1
        }

        test_event2_filter = %EventFilter{
          event_type: TestEvent2
        }

        Messenger.subscribe_message(id, __MODULE__, test_event1_filter)
        Messenger.subscribe_message(id, __MODULE__, test_event2_filter)

        send(pid, :launched)

        send(pid, perform(id, %Receive{event_filter: test_event1_filter}))
        send(pid, perform(id, %Receive{event_filter: test_event2_filter}))

        Automaton.finish()
      end
    end

    test "works with Automaton" do
      saga_id = SagaID.new()
      Dispatcher.listen_event_body(%Saga.Finish{id: saga_id})

      Dispatcher.dispatch(
        Event.new(%StartSaga{
          id: saga_id,
          saga: %TestAutomaton{pid: self()}
        })
      )

      assert_receive :launched

      event1 = Event.new(%TestEvent1{value: 1})
      Dispatcher.dispatch(event1)

      assert_receive ^event1

      event2 = Event.new(%TestEvent2{value: 2})
      Dispatcher.dispatch(event2)

      assert_receive ^event2

      assert_receive %Event{body: %Saga.Finish{id: ^saga_id}}

      TestHelper.ensure_finished(saga_id)
    end
  end
end
