defmodule Cizen.Effects.End do
  @moduledoc """
  An effect to end a saga.

  Returns the saga ID.

  ## Example
      saga_id = perform id, %End{
        saga_id: some_saga_id
      }
  """

  defstruct [:saga_id]

  alias Cizen.Effect
  alias Cizen.Effects.{Dispatch, Map}

  alias Cizen.EndSaga

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