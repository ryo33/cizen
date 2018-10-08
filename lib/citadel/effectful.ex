defmodule Citadel.Effectful do
  @moduledoc """
  Creates a block which can perform effects.
  """

  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.SagaID

  alias Citadel.StartSaga

  defmacro __using__(_opts) do
    quote do
      import Citadel.Effectful, only: [handle: 1]
      import Citadel.Automaton, only: [perform: 2]
      require Citadel.EventFilter
    end
  end

  defmacro handle(func) do
    alias __MODULE__.InstantAutomaton

    quote do
      pid = self()

      Dispatcher.dispatch(
        Event.new(%StartSaga{
          id: SagaID.new(),
          saga: %InstantAutomaton{
            block: fn id ->
              send(pid, unquote(func).(id))
            end
          }
        })
      )

      receive do
        result -> result
      end
    end
  end

  defmodule InstantAutomaton do
    @moduledoc false
    alias Citadel.Automaton
    use Automaton

    defstruct [:block]

    @impl true
    def spawn(_id, struct) do
      struct
    end

    @impl true
    def yield(id, %__MODULE__{block: block}) do
      block.(id)
      Automaton.finish()
    end
  end
end
