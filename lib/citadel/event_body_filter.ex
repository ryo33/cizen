defmodule Citadel.EventBodyFilter do
  @moduledoc """
  A behaviour module to define an event filter.
  """

  @type t :: %__MODULE__{}

  alias Citadel.EventBody

  @keys [:module, :opts]
  @enforce_keys @keys
  defstruct @keys

  @callback test(EventBody.t(), opts :: term) :: boolean

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

  @spec test(__MODULE__.t(), EventBody.t()) :: boolean
  def test(%__MODULE__{module: module, opts: opts}, event_body) do
    module.test(event_body, opts)
  end
end
