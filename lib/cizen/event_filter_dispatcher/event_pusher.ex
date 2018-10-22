defmodule Cizen.EventFilterDispatcher.EventPusher do
  @moduledoc """
  Push event to subscribers
  """

  use GenServer

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.EventFilterDispatcher.PushEvent
  alias Cizen.SagaRegistry

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_args) do
    Dispatcher.listen_event_type(PushEvent)
    {:ok, :ok}
  end

  @impl true
  def handle_info(%Event{body: %PushEvent{saga_id: saga_id}} = event, state) do
    case SagaRegistry.get_pid(saga_id) do
      {:ok, pid} -> send(pid, event)
      _ -> :ok
    end

    {:noreply, state}
  end
end
