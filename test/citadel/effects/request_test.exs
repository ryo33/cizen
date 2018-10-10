defmodule Cizen.Effects.RequestTest do
  use Cizen.SagaCase

  alias Cizen.Automaton
  alias Cizen.Dispatcher
  alias Cizen.Effect
  alias Cizen.Effects
  alias Cizen.Event
  alias Cizen.EventFilter
  alias Cizen.EventID
  alias Cizen.Saga
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
      saga_id = SagaID.new()

      {effect, state} =
        Effect.init(saga_id, %Effects.Request{
          body: %TestRequest{value: 1}
        })

      response = %TestRequest.TestResponse{value: 2}

      event =
        Event.new(%Request.Response{
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
      saga_id = SagaID.new()
      Dispatcher.listen_event_body(%Saga.Finish{id: saga_id})

      spawn_link(fn ->
        Dispatcher.listen_event_type(TestRequest)

        receive do
          %Event{body: %TestRequest{value: value}} ->
            Dispatcher.dispatch(Event.new(%TestRequest.TestResponse{value: value + 1}))
        end
      end)

      Dispatcher.dispatch(
        Event.new(%StartSaga{
          id: saga_id,
          saga: %TestAutomaton{pid: self()}
        })
      )

      assert_receive %Event{body: %TestRequest.TestResponse{value: 2}}
    end
  end
end
