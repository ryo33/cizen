defmodule Cizen.Effectful do
  @moduledoc """
  Creates a block which can perform effects.

  ## Example
      use Cizen.Effectful

      handle(fn id ->
        some_result = perform id, some_effect
        if some_result do
          perform id, other_effect
        end
      end)
  """

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.SagaID

  alias Cizen.StartSaga

  defmacro __using__(_opts) do
    quote do
      import Cizen.Effectful, only: [handle: 1]
      import Cizen.Automaton, only: [perform: 2]
      require Cizen.Filter
    end
  end

  defmodule InstantAutomaton do
    @moduledoc false
    alias Cizen.Automaton
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

  def handle(func) do
    task =
      Task.async(fn ->
        pid = self()

        Dispatcher.dispatch(
          Event.new(nil, %StartSaga{
            id: SagaID.new(),
            saga: %InstantAutomaton{
              block: fn id ->
                send(pid, func.(id))
              end
            }
          })
        )

        receive do
          result -> result
        end
      end)

    Task.await(task, :infinity)
  end
end
