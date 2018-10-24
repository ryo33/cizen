defmodule Cizen.Effects.ForkTest do
  use Cizen.SagaCase
  alias Cizen.TestSaga

  alias Cizen.Dispatcher
  alias Cizen.Effects.Fork
  alias Cizen.Event
  alias Cizen.EventFilter
  alias Cizen.Saga

  defmodule(TestEvent, do: defstruct([]))

  defmodule TestAutomaton do
    alias Cizen.Automaton
    use Automaton
    defstruct [:pid]

    use Cizen.Effects

    @impl true
    def spawn(id, %__MODULE__{pid: pid}) do
      perform id, %Subscribe{event_filter: EventFilter.new(event_type: TestEvent)}

      forked =
        perform id, %Fork{
          saga: %TestSaga{}
        }

      send(pid, forked)

      :next
    end

    @impl true
    def yield(id, :next) do
      perform id, %Receive{}
      Automaton.finish()
    end
  end

  test "forked saga finishes after forker saga finishes" do
    pid = self()

    assert_handle(fn id ->
      perform id, %Start{saga: %TestAutomaton{pid: pid}}
    end)

    forked =
      receive do
        forked -> forked
      end

    Dispatcher.listen_event_type(Saga.Finished)

    Dispatcher.dispatch(Event.new(nil, %TestEvent{}))

    assert_receive %Event{body: %Saga.Finished{id: ^forked}}
  end
end
