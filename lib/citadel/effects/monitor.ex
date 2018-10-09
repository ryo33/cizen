defmodule Citadel.Effects.Monitor do
  @moduledoc """
  An effect to monitor a saga.

  Returns an event filter for MonitorSaga.Down event.

  ## Example
      down_filter = perform id, %Monitor{
        saga_id: some_id
      }
      event = perform id, %Subscribe{
        event_filter: down_filter
      }
  """

  defstruct [:saga_id]

  alias Citadel.Effect
  alias Citadel.Effects.{Dispatch, Map}
  alias Citadel.EventFilter

  alias Citadel.MonitorSaga

  @behaviour Effect

  @impl true
  def init(id, %__MODULE__{saga_id: saga_id}) do
    require Citadel.EventFilter

    effect = %Map{
      effect: %Dispatch{
        body: %MonitorSaga{
          monitor_saga_id: id,
          target_saga_id: saga_id
        }
      },
      transform: fn _response ->
        EventFilter.new(
          event_type: MonitorSaga.Down,
          event_body_filters: [
            %MonitorSaga.Down.TargetSagaIDFilter{value: saga_id}
          ]
        )
      end
    }

    {:alias_of, effect}
  end

  @impl true
  def handle_event(_, _, _, _), do: :ok
end
