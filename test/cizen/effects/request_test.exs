defmodule Cizen.Effects.RequestTest do
  use Cizen.SagaCase
  alias Cizen.TestHelper

  alias Cizen.Automaton
  alias Cizen.Dispatcher
  alias Cizen.Effect
  alias Cizen.Effects
  alias Cizen.Effects.Request.ReceiveResponseOrTimeout
  alias Cizen.Event
  alias Cizen.EventID
  alias Cizen.Filter
  alias Cizen.SagaID

  alias Cizen.Request
  alias Cizen.StartSaga

  defmodule TestRequest do
    alias Cizen.Filter

    defstruct [:value]

    defmodule TestResponse do
      defstruct [:value]
    end

    @behaviour Request

    @impl true
    def response_event_filter(%Event{}) do
      Filter.new(fn %Event{body: %TestResponse{}} -> true end)
    end
  end

  describe "Request" do
    test "dispatches Request event" do
      Dispatcher.listen_event_type(Request)

      assert_handle(fn id ->
        perform id, %Effects.Request{
          body: %TestRequest{value: 42},
          timeout: 10
        }
      end)

      assert_receive %Event{
        body: %Request{requestor_saga_id: _, body: %TestRequest{value: 42}, timeout: 10}
      }
    end

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

    test "does not resolves on a timeout for another request" do
      saga_id = TestHelper.launch_test_saga()

      {effect, state} =
        Effect.init(saga_id, %Effects.Request{
          body: %TestRequest{value: 1},
          timeout: 10
        })

      event =
        Event.new(nil, %Request.Timeout{
          requestor_saga_id: saga_id,
          request_event_id: EventID.new()
        })

      refute match?({:resolve, _}, Effect.handle_event(saga_id, event, effect, state))
    end

    defmodule TestAutomaton do
      use Automaton

      defstruct [:pid, timeout: 5000]

      @impl true
      def yield(id, %__MODULE__{pid: pid, timeout: timeout}) do
        send(
          pid,
          perform(id, %Effects.Request{
            body: %TestRequest{value: 1},
            timeout: timeout
          })
        )

        Automaton.finish()
      end
    end

    test "works Response with Automaton" do
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

    test "works Timeout with Automaton" do
      spawn_link(fn ->
        Dispatcher.listen_event_type(TestRequest)

        receive do
          %Event{body: %TestRequest{value: value}} ->
            :timer.sleep(110)
            Dispatcher.dispatch(Event.new(nil, %TestRequest.TestResponse{value: value + 1}))
        end
      end)

      Dispatcher.dispatch(
        Event.new(nil, %StartSaga{
          id: SagaID.new(),
          saga: %TestAutomaton{pid: self(), timeout: 100}
        })
      )

      assert_receive %Event{body: %Request.Timeout{}}, 1_000
    end
  end

  defp setup_receive_response(_context) do
    id = SagaID.new()
    request_id = EventID.new()

    effect = %ReceiveResponseOrTimeout{
      request_event_id: request_id
    }

    %{handler: id, request: request_id, effect: effect}
  end

  describe "ReceiveResponseOrTimeout" do
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

    test "resolves on Timeout event", %{handler: id, request: request, effect: effect} do
      {_, state} = Effect.init(id, effect)

      event =
        Event.new(nil, %Request.Timeout{
          requestor_saga_id: SagaID.new(),
          request_event_id: request
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
