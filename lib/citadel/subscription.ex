defmodule Citadel.Subscription do
  @moduledoc """
  A struct to represent event subscription.
  """

  alias Citadel.FilterSet
  alias Citadel.SagaID

  @type t :: %__MODULE__{}

  @keys [:saga_id, :filter_set]
  @enforce_keys @keys
  defstruct @keys

  @doc """
  Create new subscription struct.
  """
  @spec new(SagaID.t(), FilterSet.t()) :: t
  def new(saga_id, filter_set) do
    %__MODULE__{
      saga_id: saga_id,
      filter_set: filter_set
    }
  end
end
