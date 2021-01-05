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
    Node.initialize()
    Registry.start_link(keys: :duplicate, name: __MODULE__)
  end

  @doc """
  Dispatch the event.
  """
  @spec dispatch(Event.t()) :: :ok
  def dispatch(event) do
    Registry.dispatch(__MODULE__, :all, fn entries ->
      for {pid, :ok} <- entries, do: send(pid, event)
    end)

    Registry.dispatch(__MODULE__, Event.type(event), fn entries ->
      for {pid, :ok} <- entries, do: send(pid, event)
    end)

    Registry.dispatch(__MODULE__, event.body, fn entries ->
      for {pid, :ok} <- entries, do: send(pid, event)
    end)

    Node.push(Node, event)
    |> Enum.each(&send(&1, event))
  end

  @doc """
  Listen all events.
  """
  @spec listen_all :: :ok
  def listen_all do
    {:ok, _} = Registry.register(__MODULE__, :all, :ok)
    :ok
  end

  @doc """
  Listen the specific event type.
  """
  @spec listen_event_type(EventType.t()) :: :ok
  def listen_event_type(event_type) do
    {:ok, _} = Registry.register(__MODULE__, event_type, :ok)
    :ok
  end

  @doc """
  Listen the specific event body.
  """
  @spec listen_event_body(EventBody.t()) :: :ok
  def listen_event_body(event_body) do
    {:ok, _} = Registry.register(__MODULE__, event_body, :ok)
    :ok
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
