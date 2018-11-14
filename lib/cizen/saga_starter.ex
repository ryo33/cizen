defmodule Cizen.SagaStarter do
  @moduledoc """
  Start a saga.
  """

  defstruct []

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.Filter
  alias Cizen.Messenger
  alias Cizen.Saga

  alias Cizen.SagaLauncher.LaunchSaga

  alias Cizen.StartSaga

  @behaviour Saga

  @impl true
  def init(id, _struct) do
    require Filter
    Messenger.subscribe_message(id, Filter.new(fn %Event{body: %StartSaga{}} -> true end))
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
