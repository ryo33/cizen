defmodule Cizen.Event do
  @moduledoc """
  Helpers to handle events
  """
  alias Cizen.EventID
  alias Cizen.EventType
  alias Cizen.SagaID

  @type body :: struct
  @type t :: %__MODULE__{
          id: EventID.t(),
          body: body,
          source_saga_id: SagaID.t() | nil,
          source_saga_module: module | nil
        }

  @enforce_keys [:id, :body]
  defstruct [
    :id,
    :body,
    :source_saga_id,
    :source_saga_module
  ]

  @spec type(t) :: EventType.t()
  def type(event), do: event.body.__struct__

  @spec new(body) :: t()
  def new(body) do
    %__MODULE__{
      id: EventID.new(),
      body: body
    }
  end

  @spec new(body, SagaID.t(), module) :: t()
  def new(body, saga_id, module \\ nil) do
    %__MODULE__{
      id: EventID.new(),
      body: body,
      source_saga_id: saga_id,
      source_saga_module: module
    }
  end
end
