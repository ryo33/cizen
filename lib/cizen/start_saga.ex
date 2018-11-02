defmodule Cizen.StartSaga do
  @moduledoc """
  An event to start a saga.
  """

  @enforce_keys [:id, :saga]
  defstruct [:id, :saga, :lifetime_pid]

  alias Cizen.Event
  alias Cizen.Filter
  alias Cizen.Saga

  @behaviour Cizen.Request
  @impl true
  def response_event_filter(%Event{body: %__MODULE__{id: id}}) do
    require Filter

    Filter.new(fn %Event{body: %Saga.Started{id: saga_id}} ->
      saga_id == id
    end)
  end
end
