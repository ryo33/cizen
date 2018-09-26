defmodule Citadel.Filter do
  @moduledoc """
  A behaviour module to define an event filter.
  """

  @type t :: %__MODULE__{}

  alias Citadel.Event

  @keys [:module, :opts]
  @enforce_keys @keys
  defstruct @keys

  @callback test(event :: Event.t(), opts :: term) :: boolean

  @doc """
  Create new filter struct.
  """
  @spec new(module, opts :: term) :: %__MODULE__{}
  def new(module, opts) do
    %__MODULE__{
      module: module,
      opts: opts
    }
  end
end
