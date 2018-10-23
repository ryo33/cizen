defmodule Cizen.EventFilterDispatcher.Subscription do
  @moduledoc """
  A struct to represent event subscription.
  """

  alias Cizen.Event
  alias Cizen.EventFilter
  alias Cizen.SagaID

  @type t :: %__MODULE__{
          proxy_saga_id: SagaID.t() | nil,
          lifetime_saga_id: SagaID.t() | nil,
          subscriber_saga_id: SagaID.t(),
          event_filter: EventFilter.t(),
          meta: term
        }

  @enforce_keys [:subscriber_saga_id, :event_filter]
  defstruct [
    :proxy_saga_id,
    :lifetime_saga_id,
    :subscriber_saga_id,
    :event_filter,
    :meta
  ]

  @spec match?(__MODULE__.t(), Event.t()) :: boolean
  def match?(subscription, event) do
    EventFilter.test(subscription.event_filter, event)
  end
end
