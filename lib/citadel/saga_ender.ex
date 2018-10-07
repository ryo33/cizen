defmodule Citadel.SagaEnder do
  @moduledoc """
  End a saga.
  """

  defstruct []

  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.EventFilter
  alias Citadel.Message
  alias Citadel.Messenger
  alias Citadel.Saga

  alias Citadel.EndSaga
  alias Citadel.ReceiveMessage

  @behaviour Saga

  @impl true
  def init(id, _struct) do
    Messenger.subscribe_message(id, __MODULE__, %EventFilter{event_type: EndSaga})
    :ok
  end

  @impl true
  def handle_event(
        id,
        %Event{
          body: %ReceiveMessage{
            message: %Message{
              event: %Event{body: %EndSaga{id: saga_id}}
            }
          }
        },
        state
      ) do
    Dispatcher.dispatch(Event.new(%Saga.Finish{id: saga_id}, id, __MODULE__))
    state
  end
end