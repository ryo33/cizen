defmodule Cizen.Effects.ReceiveTest do
  use Cizen.SagaCase

  alias Cizen.Automaton
  alias Cizen.Dispatcher
  alias Cizen.Effect
  alias Cizen.Effects.Receive
  alias Cizen.Event
  alias Cizen.Filter
  alias Cizen.Messenger
  alias Cizen.Saga
  alias Cizen.SagaID

  alias Cizen.StartSaga

  defmodule(TestEvent1, do: defstruct([:value]))
  defmodule(TestEvent2, do: defstruct([:value]))

  defp setup_receive(_context) do
    id = SagaID.new()

    effect = %Receive{
      event_filter: Filter.new(fn %Event{body: %TestEvent1{}} -> true end)
    }

    %{handler: id, effect: effect}
  end

  describe "Receive" do
    setup [:setup_receive]

    test "does not resolves on init", %{handler: id, effect: effect} do
      refute match?({:resolve, _}, Effect.init(id, effect))
    end

    test "resolves if matched", %{handler: id, effect: effect} do
      {_, state} = Effect.init(id, effect)

      event = Event.new(nil, %TestEvent1{})
      assert {:resolve, ^event} = Effect.handle_event(id, event, effect, state)
    end

    test "does not resolve or consume a Response event", %{handler: id} do
      alias Cizen.EventID
      alias Cizen.Request
      alias Cizen.SagaID

      {effect, state} = Effect.init(id, %Receive{})

      response_event = %Request.Response{
        requestor_saga_id: SagaID.new(),
        request_event_id: EventID.new(),
        event: %TestEvent2{}
      }

      next = Effect.handle_event(id, Event.new(nil, response_event), effect, state)

      refute match?(
               {:resolve, _},
               next
             )

      refute match?(
               {:consume, _},
               next
             )
    end

    test "does not resolve or consume a Timeout event", %{handler: id} do
      alias Cizen.EventID
      alias Cizen.Request
      alias Cizen.SagaID

      {effect, state} = Effect.init(id, %Receive{})

      timeout_event = %Request.Timeout{
        requestor_saga_id: SagaID.new(),
        request_event_id: EventID.new()
      }

      next = Effect.handle_event(id, Event.new(nil, timeout_event), effect, state)

      refute match?(
               {:resolve, _},
               next
             )

      refute match?(
               {:consume, _},
               next
             )
    end

    test "does not resolve or consume if not matched", %{handler: id, effect: effect} do
      {_, state} = Effect.init(id, effect)

      next = Effect.handle_event(id, Event.new(nil, %TestEvent2{}), effect, state)

      refute match?(
               {:resolve, _},
               next
             )

      refute match?(
               {:consume, _},
               next
             )
    end

    test "uses the default event filter" do
      assert %Receive{} == %Receive{event_filter: %Filter{}}
    end

    defmodule TestAutomaton do
      use Automaton

      defstruct [:pid]

      @impl true
      def yield(id, %__MODULE__{pid: pid}) do
        test_event1_filter = Filter.new(fn %Event{body: %TestEvent1{}} -> true end)

        test_event2_filter = Filter.new(fn %Event{body: %TestEvent2{}} -> true end)

        Messenger.subscribe_message(id, test_event1_filter)
        Messenger.subscribe_message(id, test_event2_filter)

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
        Event.new(nil, %StartSaga{
          id: saga_id,
          saga: %TestAutomaton{pid: self()}
        })
      )

      assert_receive :launched

      event1 = Event.new(nil, %TestEvent1{value: 1})
      Dispatcher.dispatch(event1)

      assert_receive ^event1

      event2 = Event.new(nil, %TestEvent2{value: 2})
      Dispatcher.dispatch(event2)

      assert_receive ^event2

      assert_receive %Event{body: %Saga.Finish{id: ^saga_id}}
    end
  end
end
