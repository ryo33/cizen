defmodule Cizen.CrashLogger do
  @moduledoc """
  A logger to log Saga.Crashed events.
  """

  use Cizen.Automaton

  defstruct []

  alias Cizen.Effects.{Receive, Subscribe}
  alias Cizen.Event
  alias Cizen.Filter
  alias Cizen.Saga

  require Logger

  def spawn(id, %__MODULE__{}) do
    perform(id, %Subscribe{
      event_filter: Filter.new(fn %Event{body: %Saga.Crashed{}} -> true end)
    })

    :loop
  end

  def yield(id, :loop) do
    crashed_event = perform(id, %Receive{})

    %Event{
      body: %Saga.Crashed{
        id: saga_id,
        reason: reason,
        stacktrace: stacktrace
      },
      source_saga: saga
    } = crashed_event

    message = """
    saga #{saga_id} is crashed
    #{inspect(saga)}
    """

    Logger.error(message <> Exception.format(:error, reason, stacktrace))

    :loop
  end
end
