defmodule Cizen.SagaStarter do
  @moduledoc """
  Start a saga.
  """

  defstruct []

  alias Cizen.CizenSagaRegistry
  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.Filter
  alias Cizen.Messenger
  alias Cizen.Saga

  alias Cizen.SagaLauncher.LaunchSaga

  alias Cizen.ForkSaga
  alias Cizen.StartSaga

  @behaviour Saga

  @impl true
  def init(id, _struct) do
    require Filter
    Messenger.subscribe_message(id, Filter.new(fn %Event{body: %StartSaga{}} -> true end))
    Messenger.subscribe_message(id, Filter.new(fn %Event{body: %ForkSaga{}} -> true end))
    :ok
  end

  @impl true
  def handle_event(
        id,
        %Event{body: %StartSaga{id: saga_id, saga: saga}},
        state
      ) do
    Dispatcher.dispatch(Event.new(id, %LaunchSaga{id: saga_id, saga: saga}))

    state
  end

  @impl true
  def handle_event(
        id,
        %Event{body: %ForkSaga{id: saga_id, saga: saga, lifetime_saga_id: lifetime}},
        state
      ) do
    case CizenSagaRegistry.get_pid(lifetime) do
      {:ok, lifetime_pid} ->
        Dispatcher.dispatch(
          Event.new(id, %LaunchSaga{id: saga_id, saga: saga, lifetime_pid: lifetime_pid})
        )

      _ ->
        :ok
    end

    state
  end
end
