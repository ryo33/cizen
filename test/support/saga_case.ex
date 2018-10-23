defmodule Cizen.SagaCase do
  @moduledoc """
  Run test with sagas.
  """
  use ExUnit.CaseTemplate
  alias Cizen.TestHelper

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.SagaLauncher

  alias Cizen.RegisterChannel

  using do
    quote do
      use Cizen.Effectful
      use Cizen.Effects
      import Cizen.SagaCase, only: [assert_handle: 1, surpress_crash_log: 0]
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
    import Cizen.Effectful, only: [handle: 1]
    current = self()

    spawn_link(fn ->
      result = handle(func)
      send(current, {:finished, result})
    end)

    receive do
      {:finished, result} -> result
    after
      1000 -> flunk("timeout assert_handle")
    end
  end

  defmodule CrashLogSurpressor do
    @moduledoc false
    use Cizen.Automaton

    alias Cizen.Effects.{Receive, Request}
    alias Cizen.EventFilter
    alias Cizen.RegisterChannel
    alias Cizen.Saga

    defstruct []

    def spawn(id, %__MODULE__{}) do
      perform(id, %Request{
        body: %RegisterChannel{
          channel_saga_id: id,
          event_filter: EventFilter.new(event_type: Saga.Crashed)
        }
      })

      :loop
    end

    def yield(id, :loop) do
      perform(id, %Receive{})

      :loop
    end
  end

  def surpress_crash_log do
    use Cizen.Effectful
    alias Cizen.Effects.Start

    handle(fn id ->
      perform(id, %Start{saga: %CrashLogSurpressor{}})
    end)
  end
end
