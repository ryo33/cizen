defmodule Citadel.EventBodyFilter do
  @moduledoc """
  A behaviour module to define an event filter.
  """

  @type t :: struct

  alias Citadel.EventBody

  @callback test(EventBody.t(), t) :: boolean

  @spec test(__MODULE__.t(), EventBody.t()) :: boolean
  def test(filter, event_body) do
    module = filter.__struct__
    module.test(filter, event_body)
  end
end
