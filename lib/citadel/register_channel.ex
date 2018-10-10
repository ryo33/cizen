defmodule Cizen.RegisterChannel do
  @moduledoc """
  An event to register a channel.
  """

  @keys [:channel, :event_filter]
  @enforce_keys @keys
  defstruct @keys

  use Cizen.Request

  defresponse Registered, :event_id do
    @moduledoc """
    An event to notify that RegisterChannel event is successfully handled.
    """
    @keys [:event_id]
    @enforce_keys @keys
    defstruct @keys
  end
end
