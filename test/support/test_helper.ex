defmodule Cizen.TestHelper do
  @moduledoc false
  import ExUnit.Assertions, only: [flunk: 0]

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.Saga
  alias Cizen.SagaID
  alias Cizen.SagaLauncher
  alias Cizen.SagaRegistry
  alias Cizen.TestSaga

  def ensure_finished(id) do
    case SagaRegistry.get_pid(id) do
      {:ok, _pid} ->
        Saga.unlaunch(id)

      _ ->
        :ok
    end
  end

  def launch_test_saga(opts \\ []) do
    pid = self()
    saga_id = SagaID.new()

    Dispatcher.dispatch(
      Event.new(%SagaLauncher.LaunchSaga{
        id: saga_id,
        saga: %TestSaga{
          launch: fn id, state ->
            send(pid, {:ok, id})
            launch = Keyword.get(opts, :launch, fn _id, state -> state end)
            state = launch.(id, state)
            state
          end,
          handle_event: Keyword.get(opts, :handle_event, fn _id, _event, state -> state end)
        }
      })
    )

    receive do
      {:ok, ^saga_id} -> :ok
    after
      1000 -> flunk()
    end

    saga_id
  end

  defmacro assert_condition(timeout, assertion) do
    quote do
      func = fn
        func, 1 ->
          assert unquote(assertion)

        func, count ->
          unless unquote(assertion) do
            :timer.sleep(1)
            func.(func, count - 1)
          end
      end

      func.(func, unquote(timeout))
    end
  end
end
