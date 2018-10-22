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

    @keys [:id, :saga]
    @enforce_keys @keys
    defstruct @keys
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
        Dispatcher.listen_event_body(%Saga.Launched{id: id})

        receive do
          %Event{body: %Saga.Launched{id: ^id}} -> :ok
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

  def handle_event(%LaunchSaga{id: id, saga: saga}, :ok) do
    Task.start_link(fn ->
      Saga.launch(id, saga)
    end)

    {:noreply, :ok}
  end

  def handle_event(%UnlaunchSaga{id: id}, :ok) do
    Task.start_link(fn ->
      Saga.unlaunch(id)
    end)

    {:noreply, :ok}
  end
end
