defmodule Cizen.SagaStarter do
  @moduledoc """
  Start a saga.
  """

  defstruct []

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.Saga

  alias Cizen.SagaLauncher.LaunchSaga

  alias Cizen.StartSaga

  use Saga

  @impl true
  def init(_id, _struct) do
    Dispatcher.listen_event_type(StartSaga)
    :ok
  end

  @impl true
  def handle_event(
        id,
        %Event{body: %StartSaga{id: saga_id, saga: saga, lifetime_saga_id: lifetime}},
        state
      ) do
    with false <- is_nil(lifetime),
         {:ok, lifetime_pid} <- Saga.get_pid(lifetime) do
      Dispatcher.dispatch(
        Event.new(id, %LaunchSaga{id: saga_id, saga: saga, lifetime_pid: lifetime_pid})
      )
    else
      true ->
        Dispatcher.dispatch(Event.new(id, %LaunchSaga{id: saga_id, saga: saga}))

      :error ->
        :ok
    end

    state
  end
end
