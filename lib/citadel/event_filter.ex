defmodule Citadel.EventFilter do
  @moduledoc """
  Filter events.
  """

  alias Citadel.Event
  alias Citadel.EventBodyFilterSet
  alias Citadel.EventType
  alias Citadel.SagaID

  @type t :: %__MODULE__{
          event_type: EventType.t() | nil,
          source_saga_id: SagaID.t() | nil,
          source_saga_module: module | nil,
          event_body_filter_set: EventBodyFilterSet.t() | nil
        }

  defstruct [
    :event_type,
    :source_saga_id,
    :source_saga_module,
    :event_body_filter_set
  ]

  @doc """
  Test event by the given filter.
  """
  @spec test(__MODULE__.t(), Event.t()) :: boolean
  def test(event_filter, event) do
    test_source_saga_id(event_filter, event) and test_source_saga_module(event_filter, event) and
      test_event_type(event_filter, event) and test_event_body_filter_set(event_filter, event)
  end

  defp test_source_saga_id(event_filter, event) do
    if is_nil(event_filter.source_saga_id) do
      true
    else
      event_filter.source_saga_id == event.source_saga_id
    end
  end

  defp test_source_saga_module(event_filter, event) do
    if is_nil(event_filter.source_saga_module) do
      true
    else
      event_filter.source_saga_module == event.source_saga_module
    end
  end

  defp test_event_type(event_filter, event) do
    if is_nil(event_filter.event_type) do
      true
    else
      event_filter.event_type == Event.type(event)
    end
  end

  defp test_event_body_filter_set(event_filter, event) do
    if is_nil(event_filter.event_body_filter_set) do
      true
    else
      EventBodyFilterSet.test(event_filter.event_body_filter_set, event.body)
    end
  end
end
