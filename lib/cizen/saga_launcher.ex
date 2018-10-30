defmodule Cizen.SagaLauncher do
  @moduledoc """
  The core module to launch automata.
  """

  use GenServer
  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.Saga
  alias Cizen.SagaID

  defmodule LaunchSaga do
    @moduledoc """
    The event to launch an saga.
    """

    @enforce_keys [:id, :saga]
    defstruct [:id, :saga, :lifetime_pid]
  end

  defmodule UnlaunchSaga do
    @moduledoc """
    The event to unlaunch an saga.
    """

    @keys [:id]
    @enforce_keys @keys
    defstruct @keys
  end

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Launch a saga synchronously.
  """
  @spec launch_saga(Saga.t()) :: SagaID.t()
  def launch_saga(saga) do
    id = SagaID.new()

    task =
      Task.async(fn ->
        Dispatcher.listen_event_body(%Saga.Started{id: id})

        receive do
          %Event{body: %Saga.Started{id: ^id}} -> :ok
        after
          1000 -> raise "timeout to launch saga"
        end
      end)

    Dispatcher.dispatch(
      Event.new(nil, %LaunchSaga{
        id: id,
        saga: saga
      })
    )

    Task.await(task)
    id
  end

  @impl true
  def init(_args) do
    Dispatcher.listen_event_type(LaunchSaga)
    Dispatcher.listen_event_type(UnlaunchSaga)
    {:ok, :ok}
  end

  @impl true
  def handle_info(%Event{body: body}, :ok) do
    handle_event(body, :ok)
  end

  def handle_event(%LaunchSaga{id: id, saga: saga, lifetime_pid: lifetime}, :ok) do
    Task.start_link(fn ->
      Saga.start_saga(id, saga, lifetime)
    end)

    {:noreply, :ok}
  end

  def handle_event(%UnlaunchSaga{id: id}, :ok) do
    Task.start_link(fn ->
      Saga.end_saga(id)
    end)

    {:noreply, :ok}
  end
end
