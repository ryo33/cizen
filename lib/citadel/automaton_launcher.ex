defmodule Citadel.AutomatonLauncher do
  @moduledoc """
  The core module to launch automata.
  """

  use GenServer
  alias Citadel.AutomatonSupervisor
  alias Citadel.Dispatcher

  defmodule Launch do
    @moduledoc """
    The event to launch an automaton.
    """

    @keys [:id, :module, :state]
    @enforce_keys @keys
    defstruct @keys
  end

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Dispatcher.listen_event_type(Launch)
    {:ok, :ok}
  end

  @impl true
  def handle_info(%Launch{id: id, module: module, state: state}, :ok) do
    Supervisor.start_child(
      AutomatonSupervisor,
      %{
        id: id,
        start: {module, :launch, [id, state]}
      }
    )

    {:noreply, :ok}
  end
end
