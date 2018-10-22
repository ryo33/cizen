defmodule Cizen.SagaMonitor do
  @moduledoc """
  Monitors a saga and finishes when the saga finishes, crashes, or doesn't exists.
  """

  defstruct []

  alias Cizen.CizenSagaRegistry
  alias Cizen.Dispatcher
  alias Cizen.Event

  alias Cizen.MonitorSaga

  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_args) do
    Dispatcher.listen_event_type(MonitorSaga)
    Dispatcher.listen_event_type(MonitorSaga.Down)
    {:ok, %{refs: %{}, target_monitors: %{}}}
  end

  @impl true
  def handle_info(%Event{body: %MonitorSaga{} = body}, state) do
    %MonitorSaga{monitor_saga_id: monitor, target_saga_id: target} = body

    if Map.has_key?(state.target_monitors, target) do
      state = update_in(state.target_monitors[target], &MapSet.put(&1, monitor))
      {:noreply, state}
    else
      state =
        case CizenSagaRegistry.get_pid(target) do
          {:ok, pid} ->
            ref = Process.monitor(pid)
            refs = Map.put(state.refs, ref, target)
            target_monitors = Map.put(state.target_monitors, target, MapSet.new([monitor]))
            %{state | refs: refs, target_monitors: target_monitors}

          :error ->
            down(monitor, target)
            state
        end

      {:noreply, state}
    end
  end

  def handle_info({:DOWN, ref, :process, _, _}, state) do
    {target, refs} = Map.pop(state.refs, ref)
    {monitors, target_monitors} = Map.pop(state.target_monitors, target)
    Enum.each(monitors, &down(&1, target))
    state = %{state | refs: refs, target_monitors: target_monitors}
    {:noreply, state}
  end

  def handle_info(%Event{body: %MonitorSaga.Down{monitor_saga_id: monitor}} = event, state) do
    case CizenSagaRegistry.get_pid(monitor) do
      {:ok, pid} ->
        send(pid, event)

      _ ->
        :ok
    end

    {:noreply, state}
  end

  defp down(monitor, target) do
    Dispatcher.dispatch(
      Event.new(nil, %MonitorSaga.Down{
        monitor_saga_id: monitor,
        target_saga_id: target
      })
    )
  end
end
