defmodule Cizen.Effects.End do
  @moduledoc """
  An effect to end a saga.

  Returns the saga ID.

  ## Example
      saga_id = perform id, %End{
        saga_id: some_saga_id
      }
  """

  @keys [:saga_id]
  @enforce_keys @keys
  defstruct @keys

  alias Cizen.Effect
  alias Cizen.Effects.{Dispatch, Map}

  alias Cizen.EndSaga

  use Effect

  @impl true
  def expand(_id, %__MODULE__{saga_id: saga_id}) do
    %Map{
      effect: %Dispatch{
        body: %EndSaga{
          id: saga_id
        }
      },
      transform: fn _response -> saga_id end
    }
  end
end
