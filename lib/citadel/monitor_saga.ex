defmodule Citadel.MonitorSaga do
  @moduledoc """
  An event to start monitering a saga.
  """

  @keys [:saga_id]
  @enforce_keys @keys
  defstruct @keys

  defmodule Down do
    @moduledoc """
    An event to tell the saga is down.
    """

    @keys [:saga_id]
    @enforce_keys @keys
    defstruct @keys
  end
end
