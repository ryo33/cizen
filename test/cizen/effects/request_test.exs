defmodule Cizen.Effects.RequestTest do
  use Cizen.SagaCase
  alias Cizen.TestHelper

  alias Cizen.Automaton
  alias Cizen.Dispatcher
  alias Cizen.Effect
  alias Cizen.Effects
  alias Cizen.Effects.Request.ReceiveResponse
  alias Cizen.Event
  alias Cizen.EventFilter
  alias Cizen.EventID
  alias Cizen.SagaID

  alias Cizen.Request
  alias Cizen.StartSaga

  defmodule TestRequest do
    alias Cizen.EventFilter

    defstruct [:value]

    defmodule TestResponse do
      defstruct [:value]
    end

    @behaviour Request

    @impl true
    def response_event_filters(%Event{}) do
      [
        %EventFilter{event_type: TestResponse}
      ]
    end
  end

  describe "Request" do
    test "does not resolves on a response for another request" do
      saga_id = TestHelper.launch_test_saga()

      {effect, state} =
        Effect.init(saga_id, %Effects.Request{
          body: %TestRequest{value: 1}
        })

      response = %TestRequest.TestResponse{value: 2}

      event =
        Event.new(nil, %Request.Response{
          requestor_saga_id: saga_id,
          request_event_id: EventID.new(),
          event: response
        })

      refute match?({:resolve, _}, Effect.handle_event(saga_id, event, effect, state))
    end

    defmodule TestAutomaton do
      use Automaton

      defstruct [:pid]

      @impl true
      def yield(id, %__MODULE__{pid: pid}) do
        send(
          pid,
          perform(id, %Effects.Request{
            body: %TestRequest{value: 1}
          })
        )

        Automaton.finish()
      end
    end

    test "works with Automaton" do
      spawn_link(fn ->
        Dispatcher.listen_event_type(TestRequest)

        receive do
          %Event{body: %TestRequest{value: value}} ->
            Dispatcher.dispatch(Event.new(nil, %TestRequest.TestResponse{value: value + 1}))
        end
      end)

      Dispatcher.dispatch(
        Event.new(nil, %StartSaga{
          id: SagaID.new(),
          saga: %TestAutomaton{pid: self()}
        })
      )

      assert_receive %Event{body: %TestRequest.TestResponse{value: 2}}
    end
  end

  defp setup_receive_response(_context) do
    id = SagaID.new()
    request_id = EventID.new()

    effect = %ReceiveResponse{
      request_event_id: request_id
    }

    %{handler: id, request: request_id, effect: effect}
  end

  describe "ReceiveResponse" do
    setup [:setup_receive_response]

    defmodule(TestEvent, do: defstruct([]))

    test "does not resolves on init", %{handler: id, effect: effect} do
      refute match?({:resolve, _}, Effect.init(id, effect))
    end

    test "resolves on Response event", %{handler: id, request: request, effect: effect} do
      {_, state} = Effect.init(id, effect)

      event =
        Event.new(nil, %Request.Response{
          requestor_saga_id: SagaID.new(),
          request_event_id: request,
          event: %TestEvent{}
        })

      assert {:resolve, ^event} = Effect.handle_event(id, event, effect, state)
    end

    test "does not resolve or consume other events", %{handler: id, effect: effect} do
      {_, state} = Effect.init(id, effect)

      next = Effect.handle_event(id, Event.new(nil, %TestEvent{}), effect, state)

      refute match?(
               {:resolve, _},
               next
             )

      refute match?(
               {:consume, _},
               next
             )
    end
  end
end
