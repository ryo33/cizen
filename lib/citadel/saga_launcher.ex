defmodule Citadel.SagaLauncher do
  @moduledoc """
  The core module to launch automata.
  """

  use GenServer
  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.Saga

  defmodule LaunchSaga do
    @moduledoc """
    The event to launch an saga.
    """

    @keys [:id, :module, :state]
    @enforce_keys @keys
    defstruct @keys
  end

  defmodule UnlaunchSaga do
    @moduledoc """
    The event to unlaunch an saga.
    """

    @keys [:id]
    @enforce_keys @keys
    defstruct @keys
  end

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_args) do
    Dispatcher.listen_event_type(LaunchSaga)
    Dispatcher.listen_event_type(UnlaunchSaga)
    {:ok, :ok}
  end

  @impl true
  def handle_info(%Event{body: body}, :ok) do
    handle_event(body, :ok)
  end

  def handle_event(%LaunchSaga{id: id, module: module, state: state}, :ok) do
    Task.start_link(fn ->
      Saga.launch(id, module, state)
    end)

    {:noreply, :ok}
  end

  def handle_event(%UnlaunchSaga{id: id}, :ok) do
    Task.start_link(fn ->
      Saga.unlaunch(id)
    end)

    {:noreply, :ok}
  end
end
