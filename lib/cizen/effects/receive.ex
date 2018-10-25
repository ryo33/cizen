defmodule Cizen.Effects.Receive do
  @moduledoc """
  An effect to receive an event which the saga is received.

  Returns the received event.

  If the `event_filter` is omitted, this receives all events.

  ## Example
      perform id, %Subscribe{
        event_filter: EventFilter.new(event_type: some_event_type)
      }

      perform id, %Receive{
        event_filter: EventFilter.new(event_type: some_event_type)
      }
  """

  alias Cizen.Effect
  alias Cizen.Event
  alias Cizen.EventFilter
  alias Cizen.Request.Response

  defstruct event_filter: %EventFilter{}

  use Effect

  @impl true
  def init(_handler, %__MODULE__{}) do
    :ok
  end

  @impl true
  def handle_event(_handler, %Event{body: %Response{}}, _, state), do: state

  def handle_event(_handler, event, effect, state) do
    if EventFilter.test(effect.event_filter, event) do
      {:resolve, event}
    else
      state
    end
  end
end
