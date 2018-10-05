defmodule Citadel.Request do
  @moduledoc """
  An event to request.
  """

  alias Citadel.Event
  alias Citadel.EventFilter

  @doc """
  Returns event filters to subscribe the response of the given event.
  """
  @callback response_event_filters(Event.t()) :: list(EventFilter.t())

  @keys [:requestor_saga_id, :body]
  @enforce_keys @keys
  defstruct @keys

  defmodule Response do
    @moduledoc """
    An event to respond to a request.
    """
    @keys [:requestor_saga_id, :request_event_id, :event]
    @enforce_keys @keys
    defstruct @keys
  end
end
