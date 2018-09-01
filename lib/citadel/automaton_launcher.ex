defmodule Citadel.AutomatonLauncher do
  @moduledoc """
  The core module to launch automata.
  """

  use GenServer
  alias Citadel.Automaton
  alias Citadel.Dispatcher
  alias Citadel.Event

  defmodule LaunchAutomaton do
    @moduledoc """
    The event to launch an automaton.
    """

    @keys [:id, :module, :state]
    @enforce_keys @keys
    defstruct @keys
  end

  defmodule UnlaunchAutomaton do
    @moduledoc """
    The event to unlaunch an automaton.
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
    Dispatcher.listen_event_type(LaunchAutomaton)
    Dispatcher.listen_event_type(UnlaunchAutomaton)
    {:ok, :ok}
  end

  @impl true
  def handle_info(%Event{body: body}, :ok) do
    yield(body, :ok)
  end

  def yield(%LaunchAutomaton{id: id, module: module, state: state}, :ok) do
    Task.start_link(fn ->
      Automaton.launch(id, module, state)
    end)

    {:noreply, :ok}
  end

  def yield(%UnlaunchAutomaton{id: id}, :ok) do
    Task.start_link(fn ->
      Automaton.unlaunch(id)
    end)

    {:noreply, :ok}
  end
end
