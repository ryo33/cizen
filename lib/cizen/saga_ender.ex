defmodule Cizen.SagaEnder do
  @moduledoc """
  End a saga.
  """

  defstruct []

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.EventFilter
  alias Cizen.Messenger
  alias Cizen.Saga

  alias Cizen.EndSaga

  @behaviour Saga

  @impl true
  def init(id, _struct) do
    Messenger.subscribe_message(id, %EventFilter{event_type: EndSaga})
    :ok
  end

  @impl true
  def handle_event(id, %Event{body: %EndSaga{id: saga_id}}, state) do
    Dispatcher.dispatch(Event.new(id, %Saga.Finish{id: saga_id}))
    state
  end
end
