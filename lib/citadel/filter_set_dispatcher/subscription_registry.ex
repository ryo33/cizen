defmodule Citadel.FilterSetDispatcher.SubscriptionRegistry do
  @moduledoc """
  A registry to store subscriptions.
  """

  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.FilterSetSubscribe
  alias Citadel.FilterSetSubscribed
  alias Citadel.SagaRegistry
  alias Citadel.Subscription

  @doc """
  Returns a list of subscriptions.
  """
  @spec subscriptions() :: list(Subscription.t())
  def subscriptions do
    records = Registry.lookup(__MODULE__, :subscriptions)
    Enum.map(records, fn {_pid, value} -> value end)
  end

  def start_link do
    Registry.start_link(keys: :duplicate, name: __MODULE__)
  end

  defmodule Registerer do
    @moduledoc false

    use GenServer

    alias Citadel.FilterSetDispatcher.SubscriptionRegistry

    def start_link do
      GenServer.start_link(__MODULE__, [], name: __MODULE__)
    end

    @impl true
    def init(_args) do
      Dispatcher.listen_event_type(FilterSetSubscribe)
      {:ok, :ok}
    end

    @impl true
    def handle_info(%Event{body: body}, :ok) do
      handle_event(body, :ok)
    end

    def handle_event(%FilterSetSubscribe{saga_id: saga_id, filter_set: filter_set}, :ok) do
      subscription = Subscription.new(saga_id, filter_set)

      case SagaRegistry.resolve_id(saga_id) do
        {:ok, pid} ->
          Task.start(fn ->
            Registry.register(SubscriptionRegistry, :subscriptions, subscription)
            Process.link(pid)
            Process.flag(:trap_exit, true)

            Dispatcher.dispatch(
              Event.new(%FilterSetSubscribed{saga_id: saga_id, filter_set: filter_set})
            )

            receive do
              _ -> :ok
            end
          end)

        _ ->
          :ok
      end

      {:noreply, :ok}
    end
  end
end
