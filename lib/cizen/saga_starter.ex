defmodule Cizen.SagaStarter do
  @moduledoc """
  Start a saga.
  """

  defstruct []

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.EventFilter
  alias Cizen.Message
  alias Cizen.Messenger
  alias Cizen.Saga

  alias Cizen.ReceiveMessage
  alias Cizen.SagaLauncher.LaunchSaga
  alias Cizen.StartSaga

  @behaviour Saga

  @impl true
  def init(id, _struct) do
    Messenger.subscribe_message(id, __MODULE__, %EventFilter{event_type: StartSaga})
    :ok
  end

  @impl true
  def handle_event(
        id,
        %Event{
          body: %ReceiveMessage{
            message: %Message{
              event: %Event{body: %StartSaga{id: saga_id, saga: saga}}
            }
          }
        },
        state
      ) do
    Dispatcher.dispatch(Event.new(%LaunchSaga{id: saga_id, saga: saga}, id, __MODULE__))
    state
  end
end