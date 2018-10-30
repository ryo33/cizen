defmodule Cizen.StartSaga do
  @moduledoc """
  An event to start a saga.
  """

  @enforce_keys [:id, :saga]
  defstruct [:id, :saga, :lifetime_pid]

  alias Cizen.Event
  alias Cizen.EventFilter
  alias Cizen.Saga

  defmodule SagaModuleFilter do
    @moduledoc """
    An event body filter to filter StartSaga by the module.
    """
    alias Cizen.StartSaga
    defstruct [:value]
    @behaviour Cizen.EventBodyFilter
    def test(%__MODULE__{value: module}, %StartSaga{saga: saga}) do
      Saga.module(saga) == module
    end
  end

  import Cizen.EventBodyFilter

  defeventbodyfilter SagaFilter, :saga do
    @moduledoc """
    An event body filter to filter StartSaga by saga struct.
    """
  end

  @behaviour Cizen.Request
  @impl true
  def response_event_filters(%Event{body: %__MODULE__{id: id}}) do
    require EventFilter

    [
      EventFilter.new(
        event_type: Saga.Started,
        event_body_filters: [
          %Saga.Started.SagaIDFilter{value: id}
        ]
      )
    ]
  end
end
