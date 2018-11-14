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

    @behaviour Saga

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

      Dispatcher.dispatch(
        Event.new(id, %MonitorSaga{
          monitor_saga_id: id,
          target_saga_id: requestor_saga_id
        })
      )

      {request_event_id, requestor_saga_id}
    end

    @impl true
    def handle_event(id, %Event{body: %MonitorSaga.Down{}}, state) do
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

  @behaviour Saga

  @impl true
  def init(_id, _saga) do
    Dispatcher.listen_event_type(Request)
    Dispatcher.listen_event_type(Request.Response)
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
    case Saga.get_pid(response.body.requestor_saga_id) do
      {:ok, pid} -> send(pid, response)
      _ -> :ok
    end

    state
  end
end
