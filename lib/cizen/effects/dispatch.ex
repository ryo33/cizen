defmodule Cizen.Effects.Dispatch do
  @moduledoc """
  An effect to dispatch an event.

  Returns the dispatched event.

  ## Example
        event = perform id, %Dispatch{
          body: some_event_body
        }
  """

  @keys [:body]
  @enforce_keys @keys
  defstruct @keys

  alias Cizen.Dispatcher
  alias Cizen.Effect
  alias Cizen.Event

  use Effect

  @impl true
  def init(handler, %__MODULE__{body: body}) do
    event = Event.new(handler, body)
    Dispatcher.dispatch(event)
    {:resolve, event}
  end

  @impl true
  def handle_event(_, _, _, _), do: nil
end
