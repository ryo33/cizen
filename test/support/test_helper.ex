defmodule Citadel.TestHelper do
  @moduledoc false
  import ExUnit.Assertions, only: [flunk: 0]
  import ExUnit.Callbacks, only: [on_exit: 1]
  import Citadel.Dispatcher, only: [listen_event_type: 1, dispatch: 1]
  alias Citadel.Event
  alias Citadel.Saga
  alias Citadel.SagaID
  alias Citadel.SagaLauncher
  alias Citadel.SagaRegistry
  alias Citadel.TestSaga

  def ensure_finished(id) do
    case SagaRegistry.resolve_id(id) do
      {:ok, _pid} ->
        listen_event_type(Saga.Finished)
        dispatch(Event.new(%Saga.Finish{id: id}))

        receive do
          %Event{body: %Saga.Finished{id: ^id}} -> :ok
        after
          50 -> :ok
        end

      :error ->
        :ok
    end
  end

  def launch_test_saga(opts \\ []) do
    pid = self()
    saga_id = SagaID.new()

    dispatch(
      Event.new(%SagaLauncher.LaunchSaga{
        id: saga_id,
        module: TestSaga,
        state: %{
          launch: fn id, state ->
            launch = Keyword.get(opts, :launch, fn _id, state -> state end)
            state = launch.(id, state)
            send(pid, {:ok, id})
            state
          end,
          handle_event: Keyword.get(opts, :handle_event, fn _id, _event, state -> state end)
        }
      })
    )

    receive do
      {:ok, ^saga_id} -> :ok
    after
      50 -> flunk()
    end

    on_exit(fn ->
      ensure_finished(saga_id)
    end)

    saga_id
  end
end
