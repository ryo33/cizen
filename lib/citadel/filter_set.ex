defmodule Citadel.FilterSet do
  @moduledoc """
  A set of filters.
  """

  alias Citadel.Event
  alias Citadel.Filter
  alias Citadel.FilterSet

  @type t :: %__MODULE__{}

  @keys [:target_event_type, :filters]
  @enforce_keys @keys
  defstruct @keys

  @doc """
  Create a new filter set from a list of filters.
  """
  @spec new(Event.t(), filters :: list(Filter.t())) :: %__MODULE__{}
  def new(target_event_type, filters \\ []) do
    %__MODULE__{
      target_event_type: target_event_type,
      filters: MapSet.new(filters)
    }
  end

  @doc """
  Test event with filters.
  """
  @spec test(FilterSet.t(), Event.t()) :: boolean
  def test(filter_set, event) do
    test_target_event_type(filter_set, event) and test_filters(filter_set, event)
  end

  defp test_target_event_type(filter_set, event) do
    filter_set.target_event_type == Event.type(event)
  end

  defp test_filters(filter_set, event) do
    Enum.all?(filter_set.filters, fn filter ->
      filter.module.test(event, filter.opts)
    end)
  end
end
