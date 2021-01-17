defmodule Cizen.RequestResponseMediatorTest do
  use Cizen.SagaCase
  alias Cizen.Test
  alias Cizen.TestHelper

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.Request
  alias Cizen.RequestResponseMediator
  alias Cizen.Saga
  alias Cizen.SagaLauncher

  defmodule TestRequest do
    alias Cizen.Filter

    defstruct []

    defmodule TestResponseA do
      defstruct [:value]
    end

    defmodule TestResponseB do
      defstruct [:value]
    end

    @behaviour Request

    @impl true
    def response_event_filter(_event) do
      Filter.new(fn
        %Event{body: %TestResponseA{}} -> true
        %Event{body: %TestResponseB{}} -> false
      end)
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

    @tag timeout: 6000
    test "dispatches a Timeout event when timeout" do
      pid = self()

      requestor_id =
        TestHelper.launch_test_saga(
          handle_event: fn _id, event, _state ->
            send(pid, event)
          end
        )

      request =
        Event.new(nil, %Request{
          requestor_saga_id: requestor_id,
          body: %TestRequest{},
          timeout: 50
        })

      Dispatcher.dispatch(request)

      :timer.sleep(50)

      request_id = request.id

      assert_receive %Event{
        body: %Request.Timeout{
          request_event_id: ^request_id,
          requestor_saga_id: ^requestor_id
        }
      }
    end

    @tag timeout: 200
    test "dispatches a Timeout event when specific timeout" do
      pid = self()

      requestor_id =
        TestHelper.launch_test_saga(
          handle_event: fn _id, event, _state ->
            send(pid, event)
          end
        )

      request =
        Event.new(nil, %Request{
          requestor_saga_id: requestor_id,
          body: %TestRequest{},
          timeout: 100
        })

      Dispatcher.dispatch(request)
      request_id = request.id

      :timer.sleep(90)

      refute_received %Event{
        body: %Request.Timeout{
          request_event_id: ^request_id,
          requestor_saga_id: ^requestor_id
        }
      }

      :timer.sleep(20)

      assert_receive %Event{
        body: %Request.Timeout{
          request_event_id: ^request_id,
          requestor_saga_id: ^requestor_id
        }
      }
    end
  end

  describe "RequestResponseMediator.do_work/1" do
    test "finishes after respond" do
      Dispatcher.listen_event_type(Request.Response)

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

      {:ok, worker_pid} =
        Task.start_link(fn ->
          RequestResponseMediator.do_work(request)
        end)

      Process.monitor(worker_pid)

      refute_received {:DOWN, _, :process, ^worker_pid, :normal}
      assert_receive %Event{body: %Request.Response{}}
      assert_receive {:DOWN, _, :process, ^worker_pid, :normal}
    end

    test "finishes after requestor finished" do
      requestor_id = TestHelper.launch_test_saga()

      request =
        Event.new(nil, %Request{
          requestor_saga_id: requestor_id,
          body: %TestRequest{}
        })

      {:ok, worker_pid} =
        Task.start_link(fn ->
          RequestResponseMediator.do_work(request)
        end)

      Process.monitor(worker_pid)

      refute_received {:DOWN, _, :process, ^worker_pid, :normal}
      Test.ensure_finished(requestor_id)
      assert_receive {:DOWN, _, :process, ^worker_pid, :normal}
    end

    @tag timeout: 200
    test "finishes after timeout" do
      Dispatcher.listen_event_type(Request.Timeout)

      requestor_id = TestHelper.launch_test_saga()

      request =
        Event.new(nil, %Request{
          requestor_saga_id: requestor_id,
          body: %TestRequest{},
          timeout: 100
        })

      {:ok, worker_pid} =
        Task.start_link(fn ->
          RequestResponseMediator.do_work(request)
        end)

      Process.monitor(worker_pid)

      :timer.sleep(90)
      refute_received {:DOWN, _, :process, ^worker_pid, :normal}
      assert_receive %Event{body: %Request.Timeout{}}
      assert_receive {:DOWN, _, :process, ^worker_pid, :normal}
    end
  end
end
