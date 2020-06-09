defmodule Cizen.Dispatcher.Node do
  use GenServer

  alias Cizen.Event
  alias Cizen.Filter.Code

  @spec start_link(Code.t(), pid) :: any
  def start_link(code, subscriber) do
    GenServer.start_link(__MODULE__, code, subscriber)
  end

  @spec push(pid, pid, Event.t()) :: :ok
  def push(node, sender, event) do
    GenServer.cast(node, {:push, sender, event})
  end

  @spec put(pid, Code.t(), pid) :: :ok
  def put(node, code, subscriber) do
    GenServer.cast(node, {:put, code, subscriber})
  end

  @spec delete(pid, Code.t(), pid) :: :ok
  def delete(node, code, subscriber) do
    GenServer.cast(node, {:delete, code, subscriber})
  end

  @impl true
  def init(command) do
  end
end
