defmodule Citadel.FilterSetSubscribe do
  @moduledoc """
  An event to subscribe events.
  """

  @keys [:saga_id, :filter_set]
  @enforce_keys @keys
  defstruct @keys
end
