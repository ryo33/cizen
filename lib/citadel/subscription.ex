defmodule Citadel.Subscription do
  @moduledoc """
  A struct to represent event subscription.
  """

  alias Citadel.Event
  alias Citadel.FilterSet
  alias Citadel.SagaID

  @type t :: %__MODULE__{
          subscriber_saga_id: SagaID.t(),
          subscriber_saga_module: module | nil,
          source_saga_id: SagaID.t() | nil,
          source_saga_module: module | nil,
          filter_set: FilterSet.t() | nil
        }

  @enforce_keys [:subscriber_saga_id]
  defstruct [
    :subscriber_saga_id,
    :subscriber_saga_module,
    :source_saga_id,
    :source_saga_module,
    :filter_set
  ]

  @spec match?(__MODULE__.t(), Event.t()) :: boolean
  def match?(subscription, event) do
    match_source_saga_id?(subscription, event) and match_source_saga_module?(subscription, event) and
      match_filter_set?(subscription, event)
  end

  defp match_source_saga_id?(subscription, event) do
    if is_nil(subscription.source_saga_id) do
      true
    else
      subscription.source_saga_id == event.source_saga_id
    end
  end

  defp match_source_saga_module?(subscription, event) do
    if is_nil(subscription.source_saga_module) do
      true
    else
      subscription.source_saga_module == event.source_saga_module
    end
  end

  defp match_filter_set?(subscription, event) do
    if is_nil(subscription.filter_set) do
      true
    else
      FilterSet.test(subscription.filter_set, event)
    end
  end
end
