defmodule Cizen.EndSaga do
  @moduledoc """
  An event to end a saga.
  """

  @keys [:id]
  @enforce_keys @keys
  defstruct @keys
end
