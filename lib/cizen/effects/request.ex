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
  alias Cizen.Effects.{Chain, Dispatch, Map}
  alias Cizen.Event
  alias Cizen.EventFilter
  alias Cizen.Request
  alias Cizen.Request.Response

  use Effect

  defmodule ReceiveResponse do
    @moduledoc false
    use Effect
    defstruct [:request_event_id]

    @impl true
    def init(_handler, %__MODULE__{}) do
      :ok
    end

    @impl true
    def handle_event(_handler, %Event{body: %Response{}} = event, effect, state) do
      if event.body.request_event_id == effect.request_event_id do
        {:resolve, event}
      else
        state
      end
    end

    def handle_event(_handler, _event, _effect, state), do: state
  end

  @impl true
  def expand(id, %__MODULE__{body: body}) do
    require EventFilter

    %Map{
      effect: %Chain{
        effects: [
          %Dispatch{body: %Request{requestor_saga_id: id, body: body}},
          fn request_event ->
            %ReceiveResponse{
              request_event_id: request_event.id
            }
          end
        ]
      },
      transform: fn [_dispatch, %Event{body: %Request.Response{event: event}}] -> event end
    }
  end
end
