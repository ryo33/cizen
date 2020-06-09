defmodule Cizen.Dispatcher.Intake do
  use GenServer

  alias Cizen.Dispatcher.Sender

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
    put_in(state.sender, pid)
  end
end
