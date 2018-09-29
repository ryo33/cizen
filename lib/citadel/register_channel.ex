defmodule Citadel.RegisterChannel do
  @moduledoc """
  An event to register a channel.
  """

  @keys [:channel, :event_filter]
  @enforce_keys @keys
  defstruct @keys

  defmodule Registered do
    @moduledoc """
    An event to notify that RegisterChannel event is successfully handled.
    """

    @keys [:event_id]
    @enforce_keys @keys
    defstruct @keys
  end
end
