defmodule Cizen.Dispatcher do
  @moduledoc """
  The dispatcher.
  """

  alias Cizen.Dispatcher.{Intake, RootNode, Node}
  alias Cizen.Event
  alias Cizen.EventBody
  alias Cizen.EventType
  alias Cizen.Filter

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
    Node.put({:global, RootNode}, true, self())
  end

  @doc """
  Listen the specific event type.
  """
  @spec listen_event_type(EventType.t()) :: :ok
  def listen_event_type(event_type) do
    IO.inspect(event_type, label: "event_type")
    %{code: code} = Filter.new(fn %Event{body: %event_type{}} -> true end)
    Node.put({:global, RootNode}, code, self())
  end

  @doc """
  Listen the specific event body.
  """
  @spec listen_event_body(EventBody.t()) :: :ok
  def listen_event_body(event_body) do
    %{code: code} = Filter.new(fn %Event{body: ^event_body} -> true end)
    Node.put({:global, RootNode}, code, self())
  end

  @doc """
  Listen events with the given event filter.
  """
  def listen(event_filter) do
    %{code: code} = event_filter
    Node.put({:global, RootNode}, code, self())
  end
end
