defmodule Cizen.Dispatcher.Sender do
  use GenServer

  def start_link(preceding) do
    GenServer.start_link(__MODULE__, preceding)
  end

  @spec wait_node(pid, pid) :: :ok
  def wait_node(sender, root_node) do
    GenServer.cast(
      sender,
      {:update, [], [], [root_node]}
    )
  end

  @spec put_subscribers_and_following_nodes(pid, pid, list(pid), list(pid)) :: :ok
  def put_subscribers_and_following_nodes(sender, from_node, subscribers, following_nodes) do
    GenServer.cast(
      sender,
      {:update, [from_node], subscribers, following_nodes}
    )
  end

  def init(preceding) do
    Process.monitor(preceding)

    state = %{
      preceding_downed: false,
      waiting_nodes: MapSet.new([]),
      event: nil,
      subscribers: MapSet.new([])
    }

    {:ok, state}
  end

  def handle_info({:DOWN, _, _, _, _}, state) do
    %{state | preceding_downed: true}
  end

  def handle_continue(:send_and_exit_if_fulfilled, state) do
    # and and
    {:noreply, state}
  end

  def handle_cast(
        {:update, from_node, subscribers, following_nodes},
        state
      ) do
  end
end
