defmodule Cizen.Effects do
  @moduledoc """
  A convenience module to use effects.
  """

  @effects [All, Chain, Dispatch, End, Map, Monitor, Race, Receive, Request, Start, Subscribe]

  defmacro __using__(opts) do
    effects = Keyword.get(opts, :only, @effects)

    for effect <- effects do
      case effect do
        Map ->
          quote do
            alias Cizen.Effects.HybridMap, as: Map
          end

        effect ->
          quote do
            alias Cizen.Effects.unquote(effect)
          end
      end
    end
  end

  defmodule HybridMap do
    defstruct [:effect, :transform]
    @behaviour Cizen.Effect

    alias Cizen.Effects.Map

    @impl true
    def init(_id, %__MODULE__{effect: effect, transform: transform}) do
      {:alias_of, %Map{effect: effect, transform: transform}}
    end

    @impl true
    def handle_event(_, _, _, _), do: :ok

    @deprecated_functions [{:replace, 3}]
    for {name, arity} <- Elixir.Map.__info__(:functions) do
      unless {name, arity} in @deprecated_functions do
        args =
          Stream.cycle([:ok])
          |> Stream.transform(0, fn _, acc ->
            {[{String.to_atom(<<?a + acc>>), [], nil}], acc + 1}
          end)
          |> Enum.take(arity)
        defdelegate unquote({name, [], args}), to: Elixir.Map
      end
    end
  end
end
