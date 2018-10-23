defmodule Cizen.Effects.DispatchTest do
  use Cizen.SagaCase
  alias Cizen.TestHelper

  alias Cizen.Automaton
  alias Cizen.Dispatcher
  alias Cizen.Effect
  alias Cizen.Effects.Dispatch
  alias Cizen.Event
  alias Cizen.Saga
  alias Cizen.SagaID

  alias Cizen.StartSaga

  defmodule(TestEvent, do: defstruct([:value]))

  defp setup_dispatch(_context) do
    id = TestHelper.launch_test_saga()

    effect = %Dispatch{
      body: %TestEvent{value: :a}
    }

    %{handler: id, effect: effect, body: %TestEvent{value: :a}}
  end

  describe "Dispatch" do
    setup [:setup_dispatch]

    test "resolves and dispatches an event on init", %{handler: id, effect: effect, body: body} do
      Dispatcher.listen_event_type(TestEvent)
      assert {:resolve, %Event{body: ^body}} = Effect.init(id, effect)
      assert_receive %Event{body: ^body}
    end

    defmodule TestAutomaton do
      use Automaton

      defstruct [:pid]

      @impl true
      def yield(id, %__MODULE__{pid: pid}) do
        send(pid, perform(id, %Dispatch{body: %TestEvent{value: :a}}))
        send(pid, perform(id, %Dispatch{body: %TestEvent{value: :b}}))

        Automaton.finish()
      end
    end

    test "works with Automaton" do
      saga_id = SagaID.new()
      Dispatcher.listen_event_type(TestEvent)
      Dispatcher.listen_event_body(%Saga.Finish{id: saga_id})

      Dispatcher.dispatch(
        Event.new(nil, %StartSaga{
          id: saga_id,
          saga: %TestAutomaton{pid: self()}
        })
      )

      event_a = assert_receive %Event{body: %TestEvent{value: :a}}
      assert_receive ^event_a

      event_b = assert_receive %Event{body: %TestEvent{value: :b}}
      assert_receive ^event_b

      assert_receive %Event{body: %Saga.Finish{id: ^saga_id}}
    end
  end
end
