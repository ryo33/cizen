defmodule Citadel.Subscribe do
  @moduledoc """
  An event to subscribe events.
  """

  @keys [:subscription]
  @enforce_keys @keys
  defstruct @keys
end
