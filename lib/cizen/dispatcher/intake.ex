defmodule Cizen.Dispatcher.Intake do
  @moduledoc false
  use GenServer

  alias Cizen.Dispatcher.{Node, Sender}

  def start_link do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def push(event) do
    {:ok, sender} = Sender.start_link(event)
    preceding = GenServer.call(__MODULE__, {:push, sender})
    Sender.register_preceding(sender, preceding)
    Sender.wait_node(sender, Node)
    Node.push(sender, event)
  end

  def init(_) do
    {:ok, nil}
  end

  def handle_call({:push, sender}, _from, preceding) do
    {:reply, preceding, sender}
  end
end
