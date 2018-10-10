defmodule Cizen.ReceiveMessage do
  @moduledoc """
  An event to send message.
  """

  @keys [:message]
  @enforce_keys @keys
  defstruct @keys
end
