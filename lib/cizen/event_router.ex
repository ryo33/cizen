defmodule Cizen.EventRouter do
  @moduledoc """
  The event router behaviour.

  See `Cizen.FilterDispatcher`.
  """

  alias Cizen.Event
  alias Cizen.Filter

  @callback start_link :: GenServer.on_start()
  @callback put(Filter.t(), term) :: term
  @callback delete(Filter.t(), term) :: term
  @callback routes(Event.t()) :: term
end
