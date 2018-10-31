defmodule Cizen.EventRouter do
  @moduledoc """
  The event router behaviour.

  See `Cizen.EventFilterDispatcher`.
  """

  alias Cizen.Event
  alias Cizen.EventFilter

  @type subscription :: {EventFilter.t(), term}

  @callback start_link :: GenServer.on_start()
  @callback put(subscription) :: term
  @callback delete(subscription) :: term
  @callback routes(Event.t()) :: term
end
