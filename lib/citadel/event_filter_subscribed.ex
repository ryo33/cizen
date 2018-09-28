defmodule Citadel.EventFilterSubscribed do
  @moduledoc """
  An event which is fired after subscription is created.
  """

  @keys [:subscription]
  @enforce_keys @keys
  defstruct @keys
end
