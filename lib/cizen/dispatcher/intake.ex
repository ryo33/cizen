defmodule Cizen.Dispatcher.Intake do
  use GenServer

  alias Cizen.Dispatcher.{Sender, Node}

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def push(event) do
    GenServer.cast(__MODULE__, {:push, event})
  end

  def init(_) do
    state = %{
      sender: nil
    }

    {:ok, state, {:continue, :start_sender}}
  end

  def handle_continue(:start_sender, state) do
    {:ok, pid} = Sender.start_link(state.sender)
    {:noreply, %{state | sender: pid}}
  end

  def handle_cast({:push, event}, state) do
    Sender.wait_node(state.sender, Node)
    Sender.put_event(state.sender, event)
    Node.push(state.sender, event)
    {:noreply, state, {:continue, :start_sender}}
  end
end
