defmodule Cizen.Effects.Fork do
  @moduledoc """
  An effect to state an saga.

  Returns the started saga ID.

  ## Example
      saga_id = perform id, %Fork{
        saga: some_saga_struct
      }
  """

  @keys [:saga]
  @enforce_keys @keys
  defstruct @keys

  alias Cizen.Effect
  alias Cizen.Effects.{Map, Request}
  alias Cizen.SagaID

  alias Cizen.StartSaga

  use Effect

  @impl true
  def expand(_id, %__MODULE__{saga: saga}) do
    saga_id = SagaID.new()

    %Map{
      effect: %Request{
        body: %StartSaga{id: saga_id, saga: saga, lifetime_pid: self()}
      },
      transform: fn _ -> saga_id end
    }
  end
end
