defmodule Cizen.RequestResponseMediatorTest do
  use Cizen.SagaCase
  alias Cizen.TestHelper

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.Request
  alias Cizen.RequestResponseMediator
  alias Cizen.Saga
  alias Cizen.SagaLauncher

  defmodule TestRequest do
    alias Cizen.EventFilter

    defstruct []

    defmodule TestResponseA do
      defstruct [:value]
    end

    defmodule TestResponseB do
      defstruct [:value]
    end

    @behaviour Request

    @impl true
    def response_event_filters(%Event{}) do
      [
        %EventFilter{event_type: TestResponseA},
        %EventFilter{event_type: TestResponseB}
      ]
    end
  end

  describe "RequestResponseMediator" do
    test "dispatches a event on Request event" do
      Dispatcher.listen_event_type(TestRequest)

      requestor_id = TestHelper.launch_test_saga()

      Dispatcher.dispatch(
        Event.new(nil, %Request{
          requestor_saga_id: requestor_id,
          body: %TestRequest{}
        })
      )

      assert_receive %Event{body: %TestRequest{}}
    end

    test "dispatches a Response event when it receives a event" do
      pid = self()

      requestor_id =
        TestHelper.launch_test_saga(
          handle_event: fn _id, event, _state ->
            send(pid, event)
          end
        )

      spawn_link(fn ->
        Dispatcher.listen_event_type(TestRequest)

        receive do
          %Event{body: %TestRequest{}} ->
            Dispatcher.dispatch(Event.new(nil, %TestRequest.TestResponseA{value: :a}))
        end
      end)

      request =
        Event.new(nil, %Request{
          requestor_saga_id: requestor_id,
          body: %TestRequest{}
        })

      Dispatcher.dispatch(request)

      request_id = request.id

      assert_receive %Event{
        body: %Request.Response{
          request_event_id: ^request_id,
          requestor_saga_id: ^requestor_id,
          event: %Event{body: %TestRequest.TestResponseA{value: :a}}
        }
      }
    end
  end

  describe "RequestResponseMediator.Worker" do
    test "finishes after respond" do
      Dispatcher.listen_event_type(Request.Response)
      Dispatcher.listen_event_type(Saga.Finish)

      requestor_id = TestHelper.launch_test_saga()

      spawn_link(fn ->
        Dispatcher.listen_event_type(TestRequest)

        receive do
          %Event{body: %TestRequest{}} ->
            Dispatcher.dispatch(Event.new(nil, %TestRequest.TestResponseA{value: :a}))
        end
      end)

      request =
        Event.new(nil, %Request{
          requestor_saga_id: requestor_id,
          body: %TestRequest{}
        })

      Dispatcher.dispatch(request)

      event = assert_receive %Event{body: %Request.Response{}}
      worker_saga_id = event.source_saga_id
      assert_receive %Event{body: %Saga.Finish{id: ^worker_saga_id}}
    end

    test "finishes after requestor finished" do
      Dispatcher.listen_event_type(SagaLauncher.LaunchSaga)
      Dispatcher.listen_event_type(Saga.Finish)

      requestor_id = TestHelper.launch_test_saga()

      request =
        Event.new(nil, %Request{
          requestor_saga_id: requestor_id,
          body: %TestRequest{}
        })

      Dispatcher.dispatch(request)

      event =
        assert_receive %Event{
          body: %SagaLauncher.LaunchSaga{
            saga: %RequestResponseMediator.Worker{}
          }
        }

      worker_saga_id = event.body.id

      TestHelper.ensure_finished(requestor_id)

      assert_receive %Event{body: %Saga.Finish{id: ^worker_saga_id}}
    end
  end
end
