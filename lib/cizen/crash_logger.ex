defmodule Cizen.CrashLogger do
  @moduledoc """
  A logger to log Saga.Crashed events.
  """

  use Cizen.Automaton

  defstruct []

  alias Cizen.Effects.{Receive, Subscribe}
  alias Cizen.EventFilter
  alias Cizen.Saga

  require Logger

  def spawn(id, %__MODULE__{}) do
    perform(id, %Subscribe{event_filter: EventFilter.new(event_type: Saga.Crashed)})
    :loop
  end

  def yield(id, :loop) do
    crashed_event = perform(id, %Receive{})

    %Saga.Crashed{
      id: saga_id,
      reason: reason,
      stacktrace: stacktrace
    } = crashed_event.body

    message = "saga #{saga_id} is crashed\n"
    Logger.error(message <> Exception.format(:error, reason, stacktrace))

    :loop
  end
end
