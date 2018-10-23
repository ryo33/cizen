defmodule Cizen.EventFilter do
  @moduledoc """
  Filter events.
  """

  alias Cizen.Event
  alias Cizen.EventBodyFilterSet
  alias Cizen.EventType
  alias Cizen.Saga
  alias Cizen.SagaFilterSet
  alias Cizen.SagaID

  @type t :: %__MODULE__{
          event_type: EventType.t() | nil,
          source_saga_id: SagaID.t() | nil,
          source_saga_module: module | nil,
          source_saga_filter_set: SagaFilterSet.t() | nil,
          event_body_filter_set: EventBodyFilterSet.t() | nil
        }

  defstruct [
    :event_type,
    :source_saga_id,
    :source_saga_module,
    :source_saga_filter_set,
    :event_body_filter_set
  ]

  @doc """
  Test event by the given filter.
  """
  @spec test(__MODULE__.t(), Event.t()) :: boolean
  def test(event_filter, event) do
    test_source_saga_id(event_filter, event) and test_source_saga_module(event_filter, event) and
      test_source_saga_filter_set(event_filter, event) and test_event_type(event_filter, event) and
      test_event_body_filter_set(event_filter, event)
  end

  defp test_source_saga_id(event_filter, event) do
    if is_nil(event_filter.source_saga_id) do
      true
    else
      event_filter.source_saga_id == event.source_saga_id
    end
  end

  defp test_source_saga_module(event_filter, event) do
    case {event_filter.source_saga_module, event.source_saga} do
      {nil, _} ->
        true

      {_, nil} ->
        false

      {source_saga_module, source_saga} ->
        source_saga_module == Saga.module(source_saga)
    end
  end

  defp test_source_saga_filter_set(event_filter, event) do
    case {event_filter.source_saga_filter_set, event.source_saga} do
      {nil, _} ->
        true

      {_, nil} ->
        false

      {source_saga_filter_set, source_saga} ->
        SagaFilterSet.test(source_saga_filter_set, source_saga)
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

  @doc """
  Returns new event filter.

  The following keys are used to create an event filter, and all of them are optional:
    * `:event_type` - an event type.
    * `:source_saga_id` - a saga ID.
    * `:event_body_filters` - a list of event body filters.
  """
  defmacro new(params \\ []) do
    {event_type, params} = Keyword.pop(params, :event_type)
    {source_saga_id, params} = Keyword.pop(params, :source_saga_id)
    {source_saga_module, params} = Keyword.pop(params, :source_saga_module)
    {source_saga_filters, params} = Keyword.pop(params, :source_saga_filters, nil)
    {event_body_filters, params} = Keyword.pop(params, :event_body_filters, [])

    unless params == [] do
      raise ArgumentError, "invalid keys: #{inspect(params)}"
    end

    with true <- not is_nil(event_type),
         expanded <- Macro.expand(event_type, __CALLER__),
         true <- is_atom(expanded),
         {:error, _} <- Code.ensure_compiled(expanded) do
      raise ArgumentError, "module not found: #{expanded}"
    end

    with true <- not is_nil(source_saga_module),
         expanded <- Macro.expand(source_saga_module, __CALLER__),
         true <- is_atom(expanded),
         {:error, _} <- Code.ensure_compiled(expanded) do
      raise ArgumentError, "module not found: #{expanded}"
    end

    source_saga_filter_set =
      if is_nil(source_saga_filters) do
        quote do: nil
      else
        quote do: SagaFilterSet.new(unquote(source_saga_filters))
      end

    quote bind_quoted: [
            event_type: event_type,
            source_saga_id: source_saga_id,
            source_saga_module: source_saga_module,
            source_saga_filter_set: source_saga_filter_set,
            event_body_filters: event_body_filters
          ] do
      %Cizen.EventFilter{
        event_type: event_type,
        source_saga_id: source_saga_id,
        source_saga_module: source_saga_module,
        source_saga_filter_set: source_saga_filter_set,
        event_body_filter_set: EventBodyFilterSet.new(event_body_filters)
      }
    end
  end
end
