defmodule Cizen.Dispatcher.Intake do
  @moduledoc false
  use GenServer

  alias Cizen.Dispatcher.{Node, Sender}

  def start_link do
    sender_count = 100

    senders =
      1..sender_count
      |> Enum.map(fn i ->
        next_sender = :"#{Sender}_#{(i + 1) |> rem(sender_count)}"
        sender = :"#{Sender}_#{i}"
        {:ok, _} = Sender.start_link(root_node: Node, next_sender: next_sender, name: sender)
        sender
      end)

    first = List.first(senders)
    Sender.allow_to_send(first)

    GenServer.start_link(__MODULE__, senders, name: __MODULE__)
  end

  def push(event) do
    GenServer.call(__MODULE__, :push)
    |> Sender.push(event)
  end

  def init(senders) do
    state = %{
      senders: List.to_tuple(senders),
      index: 0
    }

    {:ok, state}
  end

  def handle_call(:push, _from, state) do
    %{senders: senders, index: index} = state

    sender = elem(senders, index)

    state = %{state | index: (index + 1) |> rem(tuple_size(senders))}

    {:reply, sender, state}
  end
end
