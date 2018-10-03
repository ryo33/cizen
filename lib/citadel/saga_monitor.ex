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
    {:ok, %{refs: %{}, sagas: MapSet.new([])}}
  end

  @impl true
  def handle_info(%Event{body: %MonitorSaga{saga_id: saga_id}}, state) do
    if MapSet.member?(state.sagas, saga_id) do
      {:noreply, state}
    else
      state =
        case SagaRegistry.resolve_id(saga_id) do
          {:ok, pid} ->
            ref = Process.monitor(pid)
            refs = Map.put(state.refs, ref, saga_id)
            sagas = MapSet.put(state.sagas, saga_id)
            %{state | refs: refs, sagas: sagas}

          :error ->
            down(saga_id)
            state
        end

      {:noreply, state}
    end
  end

  def handle_info({:DOWN, ref, :process, _, _}, state) do
    {saga_id, refs} = Map.pop(state.refs, ref)
    sagas = MapSet.delete(state.sagas, saga_id)
    down(saga_id)
    state = %{state | refs: refs, sagas: sagas}
    {:noreply, state}
  end

  defp down(id) do
    Dispatcher.dispatch(Event.new(%MonitorSaga.Down{saga_id: id}))
  end
end
