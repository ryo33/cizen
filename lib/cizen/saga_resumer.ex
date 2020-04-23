defmodule Cizen.SagaResumer do
  @moduledoc """
  Resume a saga.
  """

  defstruct []

  use GenServer
  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.Saga

  alias Cizen.ResumeSaga

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_args) do
    Dispatcher.listen_event_type(ResumeSaga)
    {:ok, :ok}
  end

  @impl true
  def handle_info(%Event{body: body}, :ok) do
    handle_event(body, :ok)
  end

  def handle_event(%ResumeSaga{id: id, saga: saga, state: state, lifetime_pid: lifetime}, :ok) do
    Task.start_link(fn ->
      Saga.resume(id, saga, state, lifetime)
    end)

    {:noreply, :ok}
  end
end
