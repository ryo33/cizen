defmodule Cizen.Message do
  @moduledoc """
  A message is communication between two sagas and transmitted by channels.
  """

  alias Cizen.Event
  alias Cizen.SagaID

  @type t :: %__MODULE__{
          event: Event.t(),
          destination_saga_id: SagaID.t(),
          destination_saga_module: module | nil
        }

  @keys [:event, :destination_saga_id, :destination_saga_module]
  @enforce_keys @keys
  defstruct @keys
end