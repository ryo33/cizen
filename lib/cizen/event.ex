defmodule Cizen.Event do
  @moduledoc """
  Helpers to handle events
  """

  alias Cizen.CizenSagaRegistry
  alias Cizen.EventID
  alias Cizen.EventType
  alias Cizen.Saga
  alias Cizen.SagaID

  @type body :: struct
  @type t :: %__MODULE__{
          id: EventID.t(),
          body: body,
          source_saga_id: SagaID.t() | nil,
          source_saga: Saga.t() | nil
        }

  @enforce_keys [:id, :body, :source_saga_id, :source_saga]
  defstruct [
    :id,
    :body,
    :source_saga_id,
    :source_saga
  ]

  @spec type(t) :: EventType.t()
  def type(event), do: event.body.__struct__

  @spec new(SagaID.t() | nil, body) :: t()
  def new(saga_id, body) do
    saga =
      if is_nil(saga_id) do
        nil
      else
        {:ok, saga} = CizenSagaRegistry.get_saga(saga_id)
        saga
      end

    %__MODULE__{
      id: EventID.new(),
      body: body,
      source_saga_id: saga_id,
      source_saga: saga
    }
  end
end
