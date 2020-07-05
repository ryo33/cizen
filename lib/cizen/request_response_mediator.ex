defmodule Cizen.RequestResponseMediator do
  @moduledoc """
  The request-response mediator saga.
  """

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.Request
  alias Cizen.Saga

  defstruct []

  use Saga

  @impl true
  def init(_id, _saga) do
    Dispatcher.listen_event_type(Request)
    Dispatcher.listen_event_type(Request.Response)
    Dispatcher.listen_event_type(Request.Timeout)
    :ok
  end

  @impl true
  def handle_event(_id, %Event{body: %Request{}} = request, state) do
    Task.start_link(fn -> do_work(request) end)

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

  def do_work(request) do
    event = Event.new(nil, request.body.body)

    module = Event.type(event)

    event
    |> module.response_event_filter()
    |> Dispatcher.listen()

    request_event_id = request.id
    requestor_saga_id = request.body.requestor_saga_id

    case Saga.get_pid(requestor_saga_id) do
      {:ok, pid} ->
        Process.monitor(pid)
        Dispatcher.dispatch(event)

        receive do
          {:DOWN, _, :process, _, _} ->
            :ok

          event ->
            Dispatcher.dispatch(
              Event.new(
                nil,
                %Request.Response{
                  request_event_id: request_event_id,
                  requestor_saga_id: requestor_saga_id,
                  event: event
                }
              )
            )
        after
          request.body.timeout ->
            Dispatcher.dispatch(
              Event.new(nil, %Request.Timeout{
                requestor_saga_id: requestor_saga_id,
                request_event_id: request_event_id
              })
            )
        end

      :error ->
        :ok
    end
  end
end
