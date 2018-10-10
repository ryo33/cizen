defmodule Cizen.Effects.Dispatch do
  @moduledoc """
  An effect to dispatch an event.

  Returns the dispatched event.

  ## Example
        event = perform id, %Dispatch{
          body: some_event_body
        }
  """

  defstruct [:body]

  alias Cizen.Dispatcher
  alias Cizen.Effect
  alias Cizen.Event

  @behaviour Effect

  @impl true
  def init(_handler, %__MODULE__{body: body}) do
    event = Event.new(body)
    Dispatcher.dispatch(event)
    {:resolve, event}
  end

  @impl true
  def handle_event(_, _, _, _), do: nil
end
