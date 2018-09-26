defmodule Citadel.FilterSet do
  @moduledoc """
  A set of filters.
  """

  alias Citadel.Filter

  @type t :: %__MODULE__{}

  @keys [:filters]
  @enforce_keys @keys
  defstruct @keys

  @doc """
  Create a new filter set from a list of filters.
  """
  @spec new(filters :: list(Filter.t())) :: %__MODULE__{}
  def new(filters) do
    %__MODULE__{
      filters: MapSet.new(filters)
    }
  end
end
