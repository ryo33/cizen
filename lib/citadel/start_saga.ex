defmodule Citadel.StartSaga do
  @moduledoc """
  An event to start a saga.
  """

  @keys [:id, :saga]
  @enforce_keys @keys
  defstruct @keys
end
