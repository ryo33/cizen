defmodule Cizen.Effects.Resume do
  @moduledoc """
  An effect to resume a saga.

  Returns the resumed saga ID.

  ## Example
      ^some_saga_id = perform id, %Resume{
        id: some_saga_id,
        saga: some_saga_struct,
        state: some_saga_state,
      }
  """

  @enforce_keys [:id, :saga, :state]
  defstruct @enforce_keys

  alias Cizen.Effect
  alias Cizen.Effects.{Map, Request}

  alias Cizen.ResumeSaga

  use Effect

  @impl true
  def expand(_id, %__MODULE__{id: saga_id, saga: saga, state: state}) do
    %Map{
      effect: %Request{
        body: %ResumeSaga{id: saga_id, saga: saga, state: state}
      },
      transform: fn _ -> saga_id end
    }
  end
end
