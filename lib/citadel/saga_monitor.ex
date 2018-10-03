defmodule Citadel.SagaMonitor do
  @moduledoc """
  Monitors a saga and finishes when the saga finishes, crashes, or doesn't exists.
  """

  defstruct []

  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.SagaRegistry

  alias Citadel.MonitorSaga

  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_args) do
    Dispatcher.listen_event_type(MonitorSaga)
    {:ok, %{}}
  end

  @impl true
  def handle_info(%Event{body: %MonitorSaga{saga_id: saga_id}}, refs) do
    refs =
      case SagaRegistry.resolve_id(saga_id) do
        {:ok, pid} ->
          ref = Process.monitor(pid)
          Map.put(refs, ref, saga_id)

        :error ->
          down(saga_id)
          refs
      end

    {:noreply, refs}
  end

  def handle_info({:DOWN, ref, :process, _, _}, refs) do
    {saga_id, refs} = Map.pop(refs, ref)
    down(saga_id)
    {:noreply, refs}
  end

  defp down(id) do
    Dispatcher.dispatch(Event.new(%MonitorSaga.Down{saga_id: id}))
  end
end
