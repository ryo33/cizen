defmodule Cizen.RequestResponseMediator do
  @moduledoc """
  The request-response mediator saga.
  """

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.FilterDispatcher
  alias Cizen.Saga
  alias Cizen.SagaID
  alias Cizen.SagaLauncher

  alias Cizen.MonitorSaga
  alias Cizen.Request

  defstruct []

  defmodule Worker do
    @moduledoc """
    The worker of request-response mediator saga.
    """

    defstruct [:request]

    defmodule Timeout do
      defstruct [:worker_id]
    end

    use Saga

    @impl true
    def init(id, %__MODULE__{request: request}) do
      event = Event.new(id, request.body.body)

      module = Event.type(event)

      event
      |> module.response_event_filter()
      |> FilterDispatcher.listen()

      Dispatcher.dispatch(event)

      request_event_id = request.id
      requestor_saga_id = request.body.requestor_saga_id

      Dispatcher.listen_event_body(%Timeout{worker_id: id})

      Dispatcher.dispatch(
        Event.new(id, %MonitorSaga{
          monitor_saga_id: id,
          target_saga_id: requestor_saga_id
        })
      )

      Task.start_link(fn ->
        :timer.sleep(request.body.timeout)
        Dispatcher.dispatch(Event.new(id, %Timeout{worker_id: id}))
      end)

      {request_event_id, requestor_saga_id}
    end

    @impl true
    def handle_event(id, %Event{body: %MonitorSaga.Down{}}, state) do
      Dispatcher.dispatch(Event.new(id, %Saga.Finish{id: id}))
      state
    end

    @impl true
    def handle_event(id, %Event{body: %Timeout{}}, state) do
      {request_event_id, requestor_saga_id} = state

      Dispatcher.dispatch(
        Event.new(id, %Request.Timeout{
          requestor_saga_id: requestor_saga_id,
          request_event_id: request_event_id
        })
      )

      Dispatcher.dispatch(Event.new(id, %Saga.Finish{id: id}))
      state
    end

    @impl true
    def handle_event(id, event, state) do
      {request_event_id, requestor_saga_id} = state

      Dispatcher.dispatch(
        Event.new(
          id,
          %Request.Response{
            request_event_id: request_event_id,
            requestor_saga_id: requestor_saga_id,
            event: event
          }
        )
      )

      Dispatcher.dispatch(Event.new(id, %Saga.Finish{id: id}))
      state
    end
  end

  use Saga

  @impl true
  def init(_id, _saga) do
    Dispatcher.listen_event_type(Request)
    Dispatcher.listen_event_type(Request.Response)
    Dispatcher.listen_event_type(Request.Timeout)
    :ok
  end

  @impl true
  def handle_event(id, %Event{body: %Request{}} = request, state) do
    Dispatcher.dispatch(
      Event.new(
        id,
        %SagaLauncher.LaunchSaga{
          id: SagaID.new(),
          saga: %Worker{request: request}
        }
      )
    )

    state
  end

  @impl true
  def handle_event(_id, %Event{body: %Request.Response{}} = response, state) do
    Saga.send_to(response.body.requestor_saga_id, response)

    state
  end

  @impl true
  def handle_event(_id, %Event{body: %Request.Timeout{}} = timeout, state) do
    Saga.send_to(timeout.body.requestor_saga_id, timeout)

    state
  end
end
