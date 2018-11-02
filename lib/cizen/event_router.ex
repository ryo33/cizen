defmodule Cizen.EventRouter do
  @moduledoc """
  The event router behaviour.

  See `Cizen.FilterDispatcher`.
  """

  alias Cizen.Event
  alias Cizen.Filter

  @type subscription :: {Filter.t(), term}

  @callback start_link :: GenServer.on_start()
  @callback put(subscription) :: term
  @callback delete(subscription) :: term
  @callback routes(Event.t()) :: term
end
