defmodule Citadel.Request do
  @moduledoc """
  An event to request.
  """

  alias Citadel.Event
  alias Citadel.EventFilter

  @doc """
  Returns event filters to subscribe the response of the given event.
  """
  @callback response_event_filters(Event.t()) :: list(EventFilter.t())

  @keys [:requestor_saga_id, :body]
  @enforce_keys @keys
  defstruct @keys

  defmodule Response do
    @moduledoc """
    An event to respond to a request.
    """
    @keys [:requestor_saga_id, :request_event_id, :event]
    @enforce_keys @keys
    defstruct @keys

    defmodule RequestEventIDFilter do
      @moduledoc """
      An event body filter to filter Response by the request event id
      """
      alias Citadel.EventBodyFilter
      @enforce_keys [:value]
      defstruct [:value]
      @behaviour EventBodyFilter
      @impl true
      def test(%__MODULE__{value: request_event_id}, event_body) do
        event_body.request_event_id == request_event_id
      end
    end
  end

  @doc """
  Defines a response event.

  ## Example
      defmodule Request do
        defstruct [:value]
        import Citadel.Request
        defresponse Response, :request_id do
          defstruct [:request_id, :value]
        end
      end
  """
  defmacro defresponse(module, key, do: block) do
    filter_name =
      key
      |> Atom.to_string()
      |> Kernel.<>("_filter")
      |> Macro.camelize()
      |> String.to_atom()

    quote do
      alias Citadel.Event
      alias Citadel.EventBodyFilter
      alias Citadel.EventBodyFilterSet
      alias Citadel.EventFilter

      defmodule unquote(module) do
        unquote(block)

        defmodule unquote(filter_name) do
          @moduledoc """
          An event body filter to filter #{__MODULE__}.#{unquote(module)} by event id
          """
          @enforce_keys [:value]
          defstruct [:value]
          @behaviour EventBodyFilter
          @impl true
          def test(%__MODULE__{value: value}, event_body) do
            Map.get(event_body, unquote(key)) == value
          end
        end
      end

      @behaviour Citadel.Request
      @impl true
      def response_event_filters(%Event{id: id}) do
        [
          %EventFilter{
            event_type: unquote(module),
            event_body_filter_set:
              EventBodyFilterSet.new([
                %unquote(filter_name){value: id}
              ])
          }
        ]
      end
    end
  end
end
