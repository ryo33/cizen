defmodule Citadel.StartSaga do
  @moduledoc """
  An event to start a saga.
  """

  @keys [:id, :saga]
  @enforce_keys @keys
  defstruct @keys

  alias Citadel.Event
  alias Citadel.EventFilter
  alias Citadel.Saga

  @behaviour Citadel.Request
  @impl true
  def response_event_filters(%Event{body: %__MODULE__{id: id}}) do
    require EventFilter

    [
      EventFilter.new(
        event_type: Saga.Launched,
        event_body_filters: [
          %Saga.Launched.SagaIDFilter{value: id}
        ]
      )
    ]
  end
end
