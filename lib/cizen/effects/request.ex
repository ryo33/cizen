defmodule Cizen.Effects.Request do
  @moduledoc """
  An effect to request.

  Returns the response event.

  ## Example
      response_event = perform id, %Effects.Request{
        body: some_request
      }
  """

  @keys [:body]
  @enforce_keys @keys
  defstruct @keys

  alias Cizen.Effect
  alias Cizen.Effects.{Chain, Dispatch, Map, Receive}
  alias Cizen.Event
  alias Cizen.EventFilter
  alias Cizen.Request

  use Effect

  @impl true
  def expand(id, %__MODULE__{body: body}) do
    require EventFilter

    %Map{
      effect: %Chain{
        effects: [
          %Dispatch{body: %Request{requestor_saga_id: id, body: body}},
          fn request_event ->
            %Receive{
              event_filter:
                EventFilter.new(
                  event_type: Request.Response,
                  event_body_filters: [
                    %Request.Response.RequestEventIDFilter{value: request_event.id}
                  ]
                )
            }
          end
        ]
      },
      transform: fn [_dispatch, %Event{body: %Request.Response{event: event}}] -> event end
    }
  end
end
