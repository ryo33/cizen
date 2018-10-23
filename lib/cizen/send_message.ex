defmodule Cizen.SendMessage do
  @moduledoc """
  An event to send message.
  """

  @keys [:event, :saga_id]
  @enforce_keys @keys
  defstruct @keys
end
