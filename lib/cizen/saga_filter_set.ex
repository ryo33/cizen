defmodule Cizen.SagaFilterSet do
  @moduledoc """
  Create a new set of event body filters.
  """

  alias Cizen.Saga
  alias Cizen.SagaFilter

  @type t :: %__MODULE__{
          saga_filters: MapSet.t(SagaFilter.t())
        }

  @keys [:saga_filters]
  @enforce_keys @keys
  defstruct @keys

  @spec new(saga_filters :: list(SagaFilter.t())) :: __MODULE__.t()
  def new(saga_filters \\ []) do
    %__MODULE__{
      saga_filters: MapSet.new(saga_filters)
    }
  end

  @spec test(__MODULE__.t(), Saga.t()) :: boolean
  def test(filter_set, saga) do
    Enum.all?(filter_set.saga_filters, fn filter ->
      SagaFilter.test(filter, saga)
    end)
  end
end
