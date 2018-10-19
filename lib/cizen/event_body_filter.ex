defmodule Cizen.EventBodyFilter do
  @moduledoc """
  A behaviour module to define an event filter.
  """

  @type t :: struct

  alias Cizen.EventBody

  @callback test(t, EventBody.t()) :: boolean

  @spec test(__MODULE__.t(), EventBody.t()) :: boolean
  def test(filter, event_body) do
    module = filter.__struct__
    module.test(filter, event_body)
  end

  @doc """
  Defines a event body filter.

  ## Example
      defmodule SomeEvent do
        defstruct [:key, :value]
        import Cizen.EventBodyFilter
        defeventbodyfilter KeyFilter, :key
        defeventbodyfilter ValueFilter, :value do
          @moduledoc "Some document"
        end
      end
  """
  defmacro defeventbodyfilter(module, key) do
    build_eventbodyfilter(module, key, do: nil)
  end

  defmacro defeventbodyfilter(module, key, do: block) do
    build_eventbodyfilter(module, key, do: block)
  end

  defp build_eventbodyfilter(module, key, do: block) do
    quote do
      defmodule unquote(module) do
        unquote(block)

        @enforce_keys [:value]
        defstruct [:value]

        @behaviour Cizen.EventBodyFilter

        @impl true
        def test(%__MODULE__{value: value}, body) do
          value == Map.get(body, unquote(key))
        end
      end
    end
  end
end
