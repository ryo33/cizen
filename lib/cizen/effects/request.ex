defmodule Cizen.Effects.Request do
  @moduledoc """
  An effect to request.

  Returns the response event or timeout event.

  When used, it accepts the following options:

    * `:body` - requested event.
    * `:timeout` - timeout for response (Defaults to 5000 milliseconds).

  ## Example
      response_or_timeout_event =
        perform id, %Effects.Request{
          body: some_request,
          timeout: 300
        }
  """

  @enforce_keys [:body]
  defstruct @enforce_keys ++ [timeout: 5000]

  alias Cizen.Effect
  alias Cizen.Effects.{Chain, Dispatch, Map}
  alias Cizen.Event
  alias Cizen.Filter
  alias Cizen.Request
  alias Cizen.Request.{Response, Timeout}

  use Effect

  defmodule ReceiveResponseOrTimeout do
    @moduledoc false
    use Effect
    defstruct [:request_event_id]

    @impl true
    def init(_handler, %__MODULE__{}) do
      :ok
    end

    @impl true
    def handle_event(_handler, %Event{body: %event_type{}} = event, effect, state)
        when event_type in [Response, Timeout] do
      if event.body.request_event_id == effect.request_event_id do
        {:resolve, event}
      else
        state
      end
    end

    def handle_event(_handler, _event, _effect, state), do: state
  end

  @impl true
  def expand(id, %__MODULE__{body: body, timeout: timeout}) do
    require Filter

    %Map{
      effect: %Chain{
        effects: [
          %Dispatch{body: %Request{requestor_saga_id: id, body: body, timeout: timeout}},
          fn request_event ->
            %ReceiveResponseOrTimeout{
              request_event_id: request_event.id
            }
          end
        ]
      },
      transform: fn
        [_dispatch, %Event{body: %Request.Response{event: event}}] -> event
        [_dispatch, %Event{body: %Request.Timeout{}} = event] -> event
      end
    }
  end
end
