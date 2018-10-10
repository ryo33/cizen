defmodule Cizen.Effects.Start do
  @moduledoc """
  An effect to state an saga.

  Returns the started saga ID.

  ## Example
      saga_id = perform id, %Start{
        saga: some_saga_struct
      }
  """

  defstruct [:saga]

  alias Cizen.Effect
  alias Cizen.Effects.{Map, Request}
  alias Cizen.SagaID

  alias Cizen.StartSaga

  @behaviour Effect

  @impl true
  def init(_id, %__MODULE__{saga: saga}) do
    saga_id = SagaID.new()

    effect = %Map{
      effect: %Request{
        body: %StartSaga{id: saga_id, saga: saga}
      },
      transform: fn _ -> saga_id end
    }

    {:alias_of, effect}
  end

  @impl true
  def handle_event(_, _, _, _), do: :ok
end
