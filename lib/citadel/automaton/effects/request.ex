defmodule Citadel.Automaton.Effects.Request do
  @moduledoc """
  An effect to request.

  Returns the response event.
  """

  defstruct [:body]

  alias Citadel.Automaton.Effect
  alias Citadel.Automaton.Effects.{Dispatch, Join, Map, Receive}
  alias Citadel.Event
  alias Citadel.EventFilter
  alias Citadel.Request

  @behaviour Effect

  @event_filter %EventFilter{
    event_type: Request.Response
  }

  @impl true
  def init(id, %__MODULE__{body: body}) do
    effect = %Map{
      effect: %Join{
        effects: [
          %Dispatch{body: %Request{requestor_saga_id: id, body: body}},
          %Receive{event_filter: @event_filter}
        ]
      },
      transform: fn [_dispatch, %Event{body: %Request.Response{event: event}}] -> event end
    }

    {:alias_of, effect}
  end

  @impl true
  def handle_event(_, _, _, _), do: :ok
end
