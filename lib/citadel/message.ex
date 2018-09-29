defmodule Citadel.Message do
  @moduledoc """
  A message is communication between two sagas and transmitted by channels.
  """

  @keys [:event, :subscriber_saga_id, :subscriber_saga_module]
  @enforce_keys @keys
  defstruct @keys
end
