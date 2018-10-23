defmodule Cizen.EventFilterDispatcher.Subscribe do
  @moduledoc """
  An event to subscribe events.
  """

  @keys [:subscription]
  @enforce_keys @keys
  defstruct @keys

  defmodule Subscribed do
    @moduledoc """
    An event which is fired after subscription is created.
    """

    @keys [:subscribe_id]
    @enforce_keys @keys
    defstruct @keys
  end
end
