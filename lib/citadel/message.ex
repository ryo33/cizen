defmodule Citadel.Message do
  @moduledoc """
  A message is communication between two sagas and transmitted by channels.
  """

  alias Citadel.Event
  alias Citadel.SagaID

  @type t :: %__MODULE__{
          event: Event.t(),
          subscriber_saga_id: SagaID.t(),
          subscriber_saga_module: module | nil
        }

  @keys [:event, :subscriber_saga_id, :subscriber_saga_module]
  @enforce_keys @keys
  defstruct @keys
end
