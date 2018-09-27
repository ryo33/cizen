defmodule Citadel.FilterSetSubscribed do
  @moduledoc """
  An event which is fired after subscription is created.
  """

  @keys [:saga_id, :filter_set]
  @enforce_keys @keys
  defstruct @keys
end
