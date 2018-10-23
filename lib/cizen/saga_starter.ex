defmodule Cizen.SagaStarter do
  @moduledoc """
  Start a saga.
  """

  defstruct []

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.EventFilter
  alias Cizen.Messenger
  alias Cizen.Saga

  alias Cizen.SagaLauncher.LaunchSaga
  alias Cizen.StartSaga

  @behaviour Saga

  @impl true
  def init(id, _struct) do
    Messenger.subscribe_message(id, %EventFilter{event_type: StartSaga})
    :ok
  end

  @impl true
  def handle_event(id, %Event{body: %StartSaga{id: saga_id, saga: saga}}, state) do
    Dispatcher.dispatch(Event.new(id, %LaunchSaga{id: saga_id, saga: saga}))
    state
  end
end
