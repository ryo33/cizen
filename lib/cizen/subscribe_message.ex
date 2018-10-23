defmodule Cizen.SubscribeMessage do
  @moduledoc """
  An event to subscribe message
  """

  @enforce_keys [:subscriber_saga_id, :event_filter]
  defstruct [
    :subscriber_saga_id,
    :event_filter,
    :lifetime_saga_id
  ]

  use Cizen.Request

  defresponse Subscribed, :event_id do
    @moduledoc """
    An event to notify that SubscribeMessage event is successfully handled.
    """
    @keys [:event_id]
    @enforce_keys @keys
    defstruct @keys
  end
end
