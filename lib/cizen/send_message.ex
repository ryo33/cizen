defmodule Cizen.SendMessage do
  @moduledoc """
  An event to send message.
  """

  @keys [:message, :channels]
  @enforce_keys @keys
  defstruct @keys
end
