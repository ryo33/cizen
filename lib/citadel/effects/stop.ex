defmodule Citadel.Effects.End do
  @moduledoc """
  An effect to end a saga.

  Returns the saga_id
  """

  defstruct [:saga_id]

  alias Citadel.Effect
  alias Citadel.Effects.{Dispatch, Map}

  alias Citadel.EndSaga

  @behaviour Effect

  @impl true
  def init(_id, %__MODULE__{saga_id: saga_id}) do
    effect = %Map{
      effect: %Dispatch{
        body: %EndSaga{
          id: saga_id
        }
      },
      transform: fn _response -> saga_id end
    }

    {:alias_of, effect}
  end

  @impl true
  def handle_event(_, _, _, _), do: :ok
end
