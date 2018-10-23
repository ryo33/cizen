defmodule Cizen.SagaFilter do
  @moduledoc """
  A behaviour module to define an event filter.
  """

  @type t :: struct

  alias Cizen.Saga

  @callback test(t, Saga.t()) :: boolean

  @spec test(__MODULE__.t(), Saga.t()) :: boolean
  def test(filter, event_body) do
    module = filter.__struct__
    module.test(filter, event_body)
  end

  @doc """
  Defines a event body filter.

  ## Example
      defmodule SomeSaga do
        defstruct [:key, :value]
        import Cizen.SagaFilter
        defsagafilter KeyFilter, :key
        defsagafilter ValueFilter, :value do
          @moduledoc "Some document"
        end

        @behaviour Cizen.Saga
        defstruct []

        @impl true
        def init(_id, _saga) do
          :ok
        end

        @impl true
        def handle_event(_id, _event, state) do
          state
        end
      end
  """
  defmacro defsagafilter(module, key) do
    build_sagafilter(module, key, do: nil)
  end

  defmacro defsagafilter(module, key, do: block) do
    build_sagafilter(module, key, do: block)
  end

  defp build_sagafilter(module, key, do: block) do
    quote do
      defmodule unquote(module) do
        unquote(block)

        @enforce_keys [:value]
        defstruct [:value]

        @behaviour Cizen.SagaFilter

        @impl true
        def test(%__MODULE__{value: value}, body) do
          value == Map.get(body, unquote(key))
        end
      end
    end
  end
end
