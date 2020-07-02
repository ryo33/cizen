defmodule Cizen.Dispatcher.Sender do
  use GenServer

  alias Cizen.Event

  def start_link(event) do
    GenServer.start_link(__MODULE__, event)
  end

  def register_preceding(sender, preceding) do
    GenServer.cast(sender, {:monitor, preceding})
  end

  @spec wait_node(pid, GenServer.server()) :: :ok
  def wait_node(sender, node) do
    GenServer.cast(
      sender,
      {:update, [], [], [node]}
    )
  end

  @spec put_subscribers_and_following_nodes(pid, pid, list(pid), list(pid)) :: :ok
  def put_subscribers_and_following_nodes(sender, from_node, subscribers, following_nodes) do
    GenServer.cast(
      sender,
      {:update, [from_node], subscribers, following_nodes}
    )
  end

  @spec put_event(pid, Event.t()) :: :ok
  def put_event(sender, event) do
    GenServer.cast(sender, {:put_event, event})
  end

  def init(event) do
    state = %{
      preceding_downed: false,
      waiting_nodes: MapSet.new([]),
      event: event,
      subscribers: MapSet.new([])
    }

    {:ok, state}
  end

  def handle_cast({:monitor, pid}, state) do
    if is_nil(pid) do
      {:noreply, %{state | preceding_downed: true}}
    else
      Process.monitor(pid)
      {:noreply, state}
    end
  end

  def handle_info({:DOWN, _, _, _, _}, state) do
    # Agent.update(:trace, fn list ->
    #   [
    #     %{
    #       event: state.event,
    #       time: NaiveDateTime.utc_now(),
    #       message: "#{__ENV__.module}.#{__ENV__.function |> elem(0)}:#{__ENV__.line}"
    #     }
    #     | list
    #   ]
    # end)

    {:noreply, %{state | preceding_downed: true}, {:continue, :send_and_exit_if_fulfilled}}
  end

  def handle_continue(:send_and_exit_if_fulfilled, state) do
    if state.preceding_downed and not is_nil(state.event) and Enum.empty?(state.waiting_nodes) do
      # Agent.update(:trace, fn list ->
      #   [
      #     %{
      #       event: state.event,
      #       time: NaiveDateTime.utc_now(),
      #       message: "#{__ENV__.module}.#{__ENV__.function |> elem(0)}:#{__ENV__.line}"
      #     }
      #     | list
      #   ]
      # end)
      Enum.map(state.subscribers, fn subscriber ->
        send(subscriber, state.event)
      end)
      # Agent.update(:trace, fn list ->
      #   [
      #     %{
      #       event: state.event,
      #       time: NaiveDateTime.utc_now(),
      #       message: "#{__ENV__.module}.#{__ENV__.function |> elem(0)}:#{__ENV__.line}"
      #     }
      #     | list
      #   ]
      # end)

      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:put_event, event}, state) do
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

    {:noreply, %{state | event: event}, {:continue, :send_and_exit_if_fulfilled}}
  end

  def handle_cast(
        {:update, from_nodes, subscribers, following_nodes},
        state
      ) do
    # Agent.update(:trace, fn list ->
    #   [
    #     %{
    #       event: state.event,
    #       time: NaiveDateTime.utc_now(),
    #       message: "#{__ENV__.module}.#{__ENV__.function |> elem(0)}:#{__ENV__.line}"
    #     }
    #     | list
    #   ]
    # end)

    state =
      state
      |> update_in([:waiting_nodes], fn nodes ->
        nodes
        |> MapSet.union(MapSet.new(following_nodes))
        |> MapSet.difference(MapSet.new(from_nodes))
      end)
      |> update_in([:subscribers], &MapSet.union(&1, MapSet.new(subscribers)))
    # Agent.update(:trace, fn list ->
    #   [
    #     %{
    #       event: state.event,
    #       time: NaiveDateTime.utc_now(),
    #       message: "#{__ENV__.module}.#{__ENV__.function |> elem(0)}:#{__ENV__.line}"
    #     }
    #     | list
    #   ]
    # end)

    {:noreply, state, {:continue, :send_and_exit_if_fulfilled}}
  end
end
