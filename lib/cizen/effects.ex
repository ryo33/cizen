defmodule Cizen.Effects do
  @moduledoc """
  A convenience module to use effects.
  """

  @effects [All, Chain, Dispatch, End, Map, Monitor, Race, Receive, Request, Start, Subscribe]

  defmacro __using__(opts) do
    effects = Keyword.get(opts, :only, @effects)

    for effect <- effects do
      quote do
        alias Cizen.Effects.unquote(effect)
      end
    end
  end
end
