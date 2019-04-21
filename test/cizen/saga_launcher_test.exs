defmodule Cizen.SagaLauncherTest do
  use Cizen.SagaCase
  doctest Cizen.SagaLauncher
  import Cizen.TestHelper, only: [launch_test_saga: 0, assert_condition: 2]

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.Saga
  alias Cizen.SagaID
  alias Cizen.SagaLauncher
  alias Cizen.TestSaga

  test "SagaLauncher.LaunchSaga event" do
    pid = self()
    saga_id = SagaID.new()

    Dispatcher.dispatch(
      Event.new(nil, %SagaLauncher.LaunchSaga{
        id: saga_id,
        saga: %TestSaga{
          init: fn id, _state ->
            send(pid, {:ok, id})
          end
        }
      })
    )

    assert_receive {:ok, saga_id}
  end

  test "SagaLauncher.UnlaunchSaga event" do
    id = launch_test_saga()
    assert {:ok, pid} = Saga.get_pid(id)
    Dispatcher.dispatch(Event.new(nil, %SagaLauncher.UnlaunchSaga{id: id}))
    assert_condition(100, Process.alive?(pid))
  end

  test "finishes the saga when the given lifetime process exits" do
    lifetime =
      spawn(fn ->
        receive do
          :finish -> :ok
        end
      end)

    saga_id = SagaID.new()

    Dispatcher.dispatch(
      Event.new(nil, %SagaLauncher.LaunchSaga{
        id: saga_id,
        saga: %TestSaga{},
        lifetime_pid: lifetime
      })
    )

    Dispatcher.listen_event_body(%Saga.Finished{id: saga_id})

    refute_receive %Event{body: %Saga.Finished{}}

    send(lifetime, :finish)

    assert_receive %Event{body: %Saga.Finished{}}
    assert_condition(100, :error == Saga.get_pid(saga_id))
  end
end
