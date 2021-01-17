defmodule Cizen.Dispatcher.Intake do
  alias Cizen.Dispatcher.{Node, Sender}

  def start_link do
    sender_count = System.schedulers_online()

    senders =
      0..(sender_count - 1)
      |> Enum.map(fn i ->
        sender = :"#{Sender}_#{i}"

        next_sender = :"#{Sender}_#{rem(i + 1, sender_count)}"

        # TODO: supervise
        {:ok, _} = Sender.start_link(root_node: Node, next_sender: next_sender, name: sender)
        sender
      end)

    first = List.first(senders)
    Sender.allow_to_send(first)

    :ets.new(__MODULE__, [:set, :public, :named_table])
    :ok
  end

  def push(event) do
    sender_count = System.schedulers_online()
    counter = :ets.update_counter(__MODULE__, :index, {2, 1}, {:index, -1})
    Sender.push(:"#{Sender}_#{rem(counter, sender_count)}", event)
  end
end
