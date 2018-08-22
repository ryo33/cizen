defmodule Citadel.Event do
  @moduledoc """
  Helpers to handle events
  """
  alias Citadel.EventID
  alias Citadel.EventType

  @type t :: %__MODULE__{}
  @type body :: struct

  @keys [:id, :body]
  @enforce_keys @keys
  defstruct @keys

  @spec type(t) :: EventType.t()
  def type(event), do: event.body.__struct__

  @spec new(body) :: t()
  def new(body) do
    %__MODULE__{
      id: EventID.new(),
      body: body
    }
  end
end
