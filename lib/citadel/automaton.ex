defmodule Citadel.Automaton do
  @moduledoc """
  The automaton behaviour
  """

  use GenServer

  alias Citadel.AutomatonID
  alias Citadel.AutomatonRegistry

  @type state :: any

  @doc false
  @callback launch(AutomatonID.t(), state) :: state

  def launch(id, module, state) do
    GenServer.start_link(__MODULE__, {id, module, state},
      name: {:via, Registry, {AutomatonRegistry, id}}
    )
  end

  def unlaunch(id) do
    :ok = GenServer.stop({:via, Registry, {AutomatonRegistry, id}}, :shutdown)
  end

  def init({id, module, state}) do
    state = module.launch(id, state)
    {:ok, {id, state}}
  end
end
