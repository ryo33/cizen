defmodule Cizen.Automaton.EffectSender do
  @moduledoc """
  Sends `Cizen.Automaton.PerformEffect` event to automata.
  """

  use GenServer

  alias Cizen.Automaton.PerformEffect
  alias Cizen.CizenSagaRegistry
  alias Cizen.Dispatcher
  alias Cizen.Event

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_args) do
    Dispatcher.listen_event_type(PerformEffect)
    {:ok, :ok}
  end

  @impl true
  def handle_info(%Event{body: %PerformEffect{handler: saga_id}} = event, state) do
    case CizenSagaRegistry.get_pid(saga_id) do
      {:ok, pid} -> send(pid, event)
      _ -> :ok
    end

    {:noreply, state}
  end
end
