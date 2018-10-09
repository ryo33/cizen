defmodule Citadel.SagaCase do
  @moduledoc """
  Run test with sagas.
  """
  use ExUnit.CaseTemplate
  alias Citadel.TestHelper

  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.SagaLauncher

  using do
    quote do
      use Citadel.Effectful
      import Citadel.SagaCase, only: [assert_handle: 1]
    end
  end

  setup do
    {:ok, agent} = Agent.start(fn -> [] end)

    pid = self()

    {:ok, task} =
      Task.start(fn ->
        Dispatcher.listen_event_type(SagaLauncher.LaunchSaga)
        send(pid, :ok)

        for :ok <- Stream.cycle([:ok]) do
          receive do
            %Event{body: %SagaLauncher.LaunchSaga{id: id}} ->
              Agent.update(agent, fn list -> [id | list] end)
          end
        end
      end)

    receive do
      :ok -> :ok
    end

    on_exit(fn ->
      sagas = Agent.get(agent, fn list -> list end)

      Enum.each(sagas, fn saga ->
        TestHelper.ensure_finished(saga)
      end)

      Process.exit(task, :kill)
      Agent.stop(agent)
    end)

    :ok
  end

  def assert_handle(func) do
    import Citadel.Effectful, only: [handle: 1]
    current = self()

    spawn_link(fn ->
      handle(func)
      send(current, :finished)
    end)

    receive do
      :finished -> :ok
    after
      1000 -> flunk("timeout assert_handle")
    end
  end
end
