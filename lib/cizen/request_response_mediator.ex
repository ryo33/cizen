defmodule Cizen.RequestResponseMediator do
  @moduledoc """
  The request-response mediator saga.
  """

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.EventFilterDispatcher
  alias Cizen.Saga
  alias Cizen.SagaID
  alias Cizen.SagaLauncher
  alias Cizen.SagaRegistry

  alias Cizen.EventFilterDispatcher.PushEvent
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
      event = Event.new(request.body.body)

      module = Event.type(event)

      event
      |> module.response_event_filters()
      |> Enum.map(
        &Task.async(fn ->
          EventFilterDispatcher.subscribe(id, __MODULE__, &1)
        end)
      )
      |> Enum.each(&Task.await(&1))

      Dispatcher.dispatch(event)

      request_event_id = request.id
      requestor_saga_id = request.body.requestor_saga_id

      Dispatcher.dispatch(
        Event.new(%MonitorSaga{
          monitor_saga_id: id,
          target_saga_id: requestor_saga_id
        })
      )

      {request_event_id, requestor_saga_id}
    end

    @impl true
    def handle_event(id, %Event{body: %PushEvent{event: event}}, state) do
      {request_event_id, requestor_saga_id} = state

      Dispatcher.dispatch(
        Event.new(
          %Request.Response{
            request_event_id: request_event_id,
            requestor_saga_id: requestor_saga_id,
            event: event
          },
          id,
          __MODULE__
        )
      )

      Dispatcher.dispatch(Event.new(%Saga.Finish{id: id}, id, __MODULE__))
      state
    end

    @impl true
    def handle_event(id, %Event{body: %MonitorSaga.Down{}}, state) do
      Dispatcher.dispatch(Event.new(%Saga.Finish{id: id}, id, __MODULE__))
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
        %SagaLauncher.LaunchSaga{
          id: SagaID.new(),
          saga: %Worker{request: request}
        },
        id,
        __MODULE__
      )
    )

    state
  end

  @impl true
  def handle_event(_id, %Event{body: %Request.Response{}} = response, state) do
    case SagaRegistry.get_pid(response.body.requestor_saga_id) do
      {:ok, pid} -> send(pid, response)
      _ -> :ok
    end

    state
  end
end
