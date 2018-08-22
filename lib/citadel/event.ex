defmodule Citadel.Event do
  @moduledoc """
  Helpers to handle events
  """
  alias Citadel.EventType

  @type t :: struct

  @spec type(t) :: EventType.t()
  def type(event), do: event.__struct__
end
