defmodule CitadelX.Dispatcher do
  @moduledoc """
  The core dispatcher
  """

  alias CitadelX.Event

  @doc false
  def start_link do
    Registry.start_link(keys: :duplicate, name: __MODULE__)
  end

  @doc """
  Dispatch an event
  """
  @spec dispatch(CitadelX.Event.t()) :: :ok
  def dispatch(event) do
    Registry.dispatch(__MODULE__, :all, fn entries ->
      for {pid, :ok} <- entries, do: send(pid, event)
    end)

    Registry.dispatch(__MODULE__, Event.type(event), fn entries ->
      for {pid, :ok} <- entries, do: send(pid, event)
    end)
  end

  @doc """
  Listen all events
  """
  @spec listen_all :: :ok
  def listen_all do
    {:ok, _} = Registry.register(__MODULE__, :all, :ok)
    :ok
  end

  @doc """
  Listen a specific event type
  """
  @spec listen_event_type(Event.Type.t()) :: :ok
  def listen_event_type(event_type) do
    {:ok, _} = Registry.register(__MODULE__, event_type, :ok)
    :ok
  end
end
