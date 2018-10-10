defmodule Cizen.EventBodyFilterSet do
  @moduledoc """
  Create a new set of event body filters.
  """

  alias Cizen.EventBody
  alias Cizen.EventBodyFilter

  @type t :: %__MODULE__{
          event_body_filters: MapSet.t(EventBodyFilter.t())
        }

  @keys [:event_body_filters]
  @enforce_keys @keys
  defstruct @keys

  @spec new(event_body_filters :: list(EventBodyFilter.t())) :: __MODULE__.t()
  def new(event_body_filters \\ []) do
    %__MODULE__{
      event_body_filters: MapSet.new(event_body_filters)
    }
  end

  @spec test(__MODULE__.t(), EventBody.t()) :: boolean
  def test(filter_set, event_body) do
    Enum.all?(filter_set.event_body_filters, fn filter ->
      EventBodyFilter.test(filter, event_body)
    end)
  end
end
