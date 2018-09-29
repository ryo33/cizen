defmodule Citadel.Transmitter do
  @moduledoc """
  Transmitter creates a connection for messaging.
  """

  use GenServer

  alias Citadel.Connection
  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.SagaID
  alias Citadel.SagaLauncher
  alias Citadel.SendMessage

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_args) do
    Dispatcher.listen_event_type(SendMessage)
    {:ok, :ok}
  end

  @impl true
  def handle_info(%Event{body: %SendMessage{} = body}, state) do
    Dispatcher.dispatch(
      Event.new(%SagaLauncher.LaunchSaga{
        id: SagaID.new(),
        module: Connection,
        state: {body.message, body.channels}
      })
    )

    {:noreply, state}
  end
end
