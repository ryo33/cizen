defmodule Cizen.Request do
  @moduledoc """
  An event to request.
  """

  alias Cizen.Event
  alias Cizen.Filter

  @doc """
  Returns event filters to subscribe the response of the given event.
  """
  @callback response_event_filter(Event.t()) :: Filter.t()

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
  end

  defmacro __using__(_opts) do
    quote do
      import Cizen.Request, only: [defresponse: 3]
      Module.register_attribute(__MODULE__, :responses, accumulate: true)
      @before_compile Cizen.Request
    end
  end

  @doc false
  defmacro __before_compile__(_env) do
    quote do
      @behaviour Cizen.Request
      @impl true
      def response_event_filter(event) do
        require Filter

        @responses
        |> Enum.map(fn {module, key} ->
          Filter.new(fn %Event{body: body} ->
            body.__struct__ == module and body[key] == event.id
          end)
        end)
        |> Filter.any()
      end
    end
  end

  @doc """
  Defines a response event.

  ## Example
      defmodule Request do
        defstruct [:value]
        use Cizen.Request
        defresponse Accept, :request_id do
          defstruct [:request_id, :value]
        end
        defresponse Reject, :request_id do
          defstruct [:request_id, :value]
        end
      end
  """
  defmacro defresponse(module, key, do: block) do
    quote do
      @responses {Module.concat(__MODULE__, unquote(module)), unquote(key)}
      defmodule unquote(module) do
        unquote(block)
      end
    end
  end
end
