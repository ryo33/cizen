defmodule Cizen.Effects.Monitor do
  @moduledoc """
  An effect to monitor a saga.

  Returns an event filter for MonitorSaga.Down event.

  ## Example
      down_filter = perform id, %Monitor{
        saga_id: some_id
      }

      # Wait until the saga finishes.
      perform(id, %Receive{
        event_filter: down_filter
      }
  """

  @keys [:saga_id]
  @enforce_keys @keys
  defstruct @keys

  alias Cizen.Effect
  alias Cizen.Effects.{Dispatch, Map}
  alias Cizen.EventFilter

  alias Cizen.MonitorSaga

  use Effect

  @impl true
  def expand(id, %__MODULE__{saga_id: saga_id}) do
    require Cizen.EventFilter

    %Map{
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
  end
end
