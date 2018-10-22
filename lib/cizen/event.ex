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
          source_saga_id: SagaID.t() | nil
        }

  @enforce_keys [:id, :body, :source_saga_id]
  defstruct [
    :id,
    :body,
    :source_saga_id
  ]

  @spec type(t) :: EventType.t()
  def type(event), do: event.body.__struct__

  @spec new(SagaID.t() | nil, body) :: t()
  def new(saga_id, body) do
    %__MODULE__{
      id: EventID.new(),
      body: body,
      source_saga_id: saga_id
    }
  end
end
