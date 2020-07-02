defmodule Cizen.Dispatcher.Intake do
  use GenServer

  alias Cizen.Dispatcher.{Sender, Node}

  def start_link do
    # GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
    Agent.start_link(fn -> nil end, name: __MODULE__)
  end

  def push(event) do
    # Agent.update(:trace, fn list ->
    #   [
    #     %{
    #       event: event,
    #       time: NaiveDateTime.utc_now(),
    #       message: "#{__ENV__.module}.#{__ENV__.function |> elem(0)}:#{__ENV__.line}"
    #     }
    #     | list
    #   ]
    # end)
    {:ok, sender} = Sender.start_link(event)
    preceding = Agent.get_and_update(__MODULE__, fn preceding -> {preceding, sender} end)
    Sender.register_preceding(sender, preceding)
    Sender.wait_node(sender, Node)
    Sender.put_event(sender, event)
    Node.push(sender, event)

    # Agent.update(:trace, fn list ->
    #   [
    #     %{
    #       event: event,
    #       time: NaiveDateTime.utc_now(),
    #       message: "#{__ENV__.module}.#{__ENV__.function |> elem(0)}:#{__ENV__.line}"
    #     }
    #     | list
    #   ]
    # end)
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
    # Agent.update(:trace, fn list ->
    #   [
    #     %{
    #       event: event,
    #       time: NaiveDateTime.utc_now(),
    #       message: "#{__ENV__.module}.#{__ENV__.function |> elem(0)}:#{__ENV__.line}"
    #     }
    #     | list
    #   ]
    # end)

    Sender.wait_node(state.sender, Node)
    Sender.put_event(state.sender, event)
    Node.push(state.sender, event)

    # Agent.update(:trace, fn list ->
    #   [
    #     %{
    #       event: event,
    #       time: NaiveDateTime.utc_now(),
    #       message: "#{__ENV__.module}.#{__ENV__.function |> elem(0)}:#{__ENV__.line}"
    #     }
    #     | list
    #   ]
    # end)
    {:noreply, state, {:continue, :start_sender}}
  end
end
