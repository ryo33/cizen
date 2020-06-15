defmodule Cizen.SagaEnder do
  @moduledoc """
  End a saga.
  """

  defstruct []

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.Filter
  alias Cizen.Saga

  alias Cizen.EndSaga

  use Saga

  @impl true
  def init(_id, _struct) do
    require Filter
    # Filter.new(fn %Event{body: %EndSaga{}} -> true end)
    # |> Dispatcher.listen()
    Dispatcher.listen_event_type(EndSaga)
    :ok
  end

  @impl true
  def handle_event(id, %Event{body: %EndSaga{id: saga_id}}, state) do
    Dispatcher.dispatch(Event.new(id, %Saga.Finish{id: saga_id}))
    state
  end
end
