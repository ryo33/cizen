defmodule Cizen.Dispatcher do
  @moduledoc """
  The dispatcher.
  """

  alias Cizen.Dispatcher.{Intake, Node}
  alias Cizen.Event
  alias Cizen.EventBody
  alias Cizen.EventType
  alias Cizen.Filter
  alias Cizen.Saga

  require Filter

  @doc false
  def start_link do
    Intake.start_link()
  end

  @doc """
  Dispatch the event.
  """
  @spec dispatch(Event.t()) :: :ok
  def dispatch(event) do
    Intake.push(event)
  end

  @doc """
  Listen all events.
  """
  @spec listen_all :: :ok
  def listen_all do
    Node.put(true, self())
  end

  @doc """
  Listen the specific event type.
  """
  @spec listen_event_type(EventType.t()) :: :ok
  def listen_event_type(event_type) do
    Filter.new(fn %Event{body: a} -> a.__struct__ == event_type end)
    |> listen()
  end

  @doc """
  Listen the specific event body.
  """
  @spec listen_event_body(EventBody.t()) :: :ok
  def listen_event_body(event_body) do
    Filter.new(fn %Event{body: ^event_body} -> true end)
    |> listen()
  end

  @doc """
  Listen events with the given event filter.
  """
  def listen(event_filter) do
    listen_with_pid(self(), event_filter)
  end

  @doc """
  Listen events with the given event filter for the given saga ID.
  """
  def listen(subscriber, event_filter) do
    case Saga.get_pid(subscriber) do
      {:ok, pid} ->
        listen_with_pid(pid, event_filter)

      _ ->
        :ok
    end
  end

  defp listen_with_pid(pid, event_filter) do
    %{code: code} = event_filter
    Node.put(code, pid)
  end
end
