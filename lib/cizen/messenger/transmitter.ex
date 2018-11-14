defmodule Cizen.Messenger.Transmitter do
  @moduledoc """
  Transmitter for messaging.
  """

  @behaviour Cizen.Saga
  defstruct []

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.Filter
  alias Cizen.Messenger
  alias Cizen.Saga

  alias Cizen.Channel.EmitMessage
  alias Cizen.Channel.FeedMessage
  alias Cizen.SendMessage

  @impl true
  def init(id, %__MODULE__{}) do
    Dispatcher.listen_event_type(SendMessage)
    Dispatcher.listen_event_type(FeedMessage)
    require Filter
    Messenger.subscribe_message(id, Filter.new(fn %Event{body: %EmitMessage{}} -> true end))
    :ok
  end

  @impl true
  def handle_event(_id, %Event{body: %SendMessage{} = body}, state) do
    case Saga.get_pid(body.saga_id) do
      {:ok, pid} -> send(pid, body.event)
      _ -> :ok
    end

    state
  end

  @impl true
  def handle_event(_id, %Event{body: %FeedMessage{}} = event, state) do
    case Saga.get_pid(event.body.channel_saga_id) do
      {:ok, pid} -> send(pid, event)
      _ -> :ok
    end

    state
  end

  @impl true
  def handle_event(id, %Event{body: %EmitMessage{} = body}, state) do
    %EmitMessage{event: event, subscribers: subscribers} = body

    Enum.each(subscribers, fn subscriber ->
      Dispatcher.dispatch(Event.new(id, %SendMessage{saga_id: subscriber, event: event}))
    end)

    state
  end
end
