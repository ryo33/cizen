defmodule Citadel.Automaton.Effects.RequestTest do
  use ExUnit.Case
  alias Citadel.TestHelper

  alias Citadel.Automaton
  alias Citadel.Automaton.Effects
  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.EventFilter
  alias Citadel.Saga
  alias Citadel.SagaID

  alias Citadel.StartSaga

  defmodule TestRequest do
    alias Citadel.EventFilter
    alias Citadel.Request

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

    test "transforms the result" do
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

      TestHelper.ensure_finished(saga_id)
    end
  end
end
