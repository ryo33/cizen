defmodule Cizen.Request do
  @moduledoc """
  An event to request.
  """

  alias Cizen.Event
  alias Cizen.EventBodyFilterSet
  alias Cizen.EventFilter

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
      alias Cizen.EventBodyFilter
      @enforce_keys [:value]
      defstruct [:value]
      @behaviour EventBodyFilter
      @impl true
      def test(%__MODULE__{value: request_event_id}, event_body) do
        event_body.request_event_id == request_event_id
      end
    end
  end

  defmacro __using__(_opts) do
    quote do
      import Cizen.Request, only: [defresponse: 3]
      Module.register_attribute(__MODULE__, :responses, accumulate: true)
      @before_compile Cizen.Request
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    alias Cizen.EventBodyFilterSet
    alias Cizen.EventFilter
    responses = Module.get_attribute(env.module, :responses)

    filters =
      Enum.map(responses, fn {module, filter} ->
        quote do
          %EventFilter{
            event_type: unquote(module),
            event_body_filter_set:
              EventBodyFilterSet.new([
                %unquote(filter){value: var!(id)}
              ])
          }
        end
      end)

    quote do
      @behaviour Cizen.Request
      @impl true
      def response_event_filters(event) do
        var!(id) = event.id
        unquote(filters)
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
    filter_name =
      key
      |> Atom.to_string()
      |> Kernel.<>("_filter")
      |> Macro.camelize()
      |> String.to_atom()

    caller = List.last(Module.split(__CALLER__.module))

    quote do
      @responses {
        Module.concat(__MODULE__, unquote(module)),
        Module.concat([__MODULE__, unquote(module), unquote(filter_name)])
      }
      defmodule unquote(module) do
        unquote(block)

        import Cizen.EventBodyFilter

        defeventbodyfilter alias!(unquote(filter_name)), unquote(key) do
          @moduledoc """
          An event body filter to filter #{unquote(caller)}.#{
            List.last(Module.split(unquote(module)))
          } by #{unquote(key)}
          """
        end
      end
    end
  end
end
