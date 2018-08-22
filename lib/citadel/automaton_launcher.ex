defmodule Citadel.AutomatonLauncher do
  @moduledoc """
  The core module to launch automata.
  """

  use GenServer
  alias Citadel.Automaton
  alias Citadel.Dispatcher

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
  def init(_opts) do
    Dispatcher.listen_event_type(LaunchAutomaton)
    {:ok, :ok}
  end

  @impl true
  def handle_info(%LaunchAutomaton{id: id, module: module, state: state}, :ok) do
    Automaton.launch(id, module, state)
    {:noreply, :ok}
  end

  @impl true
  def handle_info(%UnlaunchAutomaton{id: id}, :ok) do
    Automaton.unlaunch(id)
    {:noreply, :ok}
  end
end
