defmodule Cizen.Saga do
  @moduledoc """
  The saga behaviour

  ## Example

      defmodule SomeSaga do
        @behaviour Cizen.Saga
        defstruct []

        @impl true
        def init(_id, saga) do
          saga
        end

        @impl true
        def handle_event(_id, _event, state) do
          state
        end
      end
  """

  @type t :: struct

  use GenServer

  alias Cizen.CizenSagaRegistry
  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.Saga
  alias Cizen.SagaID

  alias Cizen.StartSaga

  @type state :: any

  @doc """
  Invoked when the saga is started.
  Saga.Launched event will be dispatched after this callback.

  Returned value will be used as the next state to pass `handle_event/3` callback.
  """
  @callback init(SagaID.t(), Saga.t()) :: state

  @doc """
  Invoked when the saga receives an event.

  Returned value will be used as the next state to pass `handle_event/3` callback.
  """
  @callback handle_event(SagaID.t(), Event.t(), state) :: state

  defmodule Finish do
    @moduledoc "A event fired to finish"
    defstruct([:id])
  end

  defmodule Launched do
    @moduledoc "A event fired on launch"
    defstruct([:id])

    import Cizen.EventBodyFilter

    defeventbodyfilter SagaIDFilter, :id do
      @moduledoc """
      An event body filter to filter Saga.Launced by saga id
      """
    end
  end

  defmodule Unlaunched do
    @moduledoc "A event fired on unlaunch"
    defstruct([:id])
  end

  defmodule Finished do
    @moduledoc "A event fired on finish"
    defstruct([:id])
  end

  defmodule Crashed do
    @moduledoc "A event fired on crash"
    defstruct([:id, :saga, :reason, :stacktrace])
  end

  @doc """
  Starts a saga which finishes when the current process exits.
  """
  @spec fork(t) :: SagaID.t()
  def fork(saga) do
    lifetime = self()
    saga_id = SagaID.new()

    task =
      Task.async(fn ->
        Dispatcher.listen_event_body(%Saga.Launched{id: saga_id})

        Dispatcher.dispatch(
          Event.new(nil, %StartSaga{id: saga_id, saga: saga, lifetime_pid: lifetime})
        )

        receive do
          %Event{body: %Saga.Launched{id: ^saga_id}} -> :ok
        end

        saga_id
      end)

    Task.await(task)

    saga_id
  end

  @lazy_launch {__MODULE__, :lazy_launch}

  def lazy_launch, do: @lazy_launch

  @doc """
  Returns the module for a saga.
  """
  @spec module(t) :: module
  def module(saga) do
    saga.__struct__
  end

  def launch(id, saga, lifetime) do
    {:ok, _pid} = GenServer.start(__MODULE__, {id, saga, lifetime})
  end

  def unlaunch(id) do
    GenServer.stop({:via, Registry, {CizenSagaRegistry, id}}, :shutdown)
  catch
    :exit, _ -> :ok
  after
    Dispatcher.dispatch(Event.new(nil, %Unlaunched{id: id}))
  end

  def exit(id, reason, trace) do
    GenServer.stop({:via, Registry, {CizenSagaRegistry, id}}, {:shutdown, {reason, trace}})
  end

  @impl true
  def init({id, saga, lifetime}) do
    unless is_nil(lifetime), do: Process.monitor(lifetime)

    Registry.register(CizenSagaRegistry, id, saga)
    Dispatcher.listen_event_body(%Finish{id: id})
    module = Saga.module(saga)

    state =
      case module.init(id, saga) do
        {@lazy_launch, state} ->
          state

        state ->
          Dispatcher.dispatch(Event.new(id, %Launched{id: id}))
          state
      end

    {:ok, {id, saga, state}}
  end

  @impl true
  def handle_info(%Event{body: %Finish{id: id}}, {id, saga, state}) do
    {:stop, {:shutdown, :finish}, {id, saga, state}}
  end

  @impl true
  def handle_info(%Event{} = event, {id, saga, state}) do
    module = Saga.module(saga)
    state = module.handle_event(id, event, state)
    {:noreply, {id, saga, state}}
  rescue
    reason -> {:stop, {:shutdown, {reason, __STACKTRACE__}}, {id, saga, state}}
  end

  @impl true
  def handle_info({:DOWN, _, :process, _, _}, state) do
    {:stop, {:shutdown, :finish}, state}
  end

  @impl true
  def terminate(:shutdown, {_id, _saga, _state}) do
    :shutdown
  end

  def terminate({:shutdown, :finish}, {id, _saga, _state}) do
    Dispatcher.dispatch(Event.new(id, %Finished{id: id}))
    :shutdown
  end

  def terminate({:shutdown, {reason, trace}}, {id, saga, _state}) do
    Dispatcher.dispatch(
      Event.new(id, %Crashed{id: id, saga: saga, reason: reason, stacktrace: trace})
    )

    :shutdown
  end

  @impl true
  def handle_call(:get_saga_id, _from, state) do
    [saga_id] = Registry.keys(CizenSagaRegistry, self())
    {:reply, saga_id, state}
  end

  def handle_call(request, _from, state) do
    result = handle_request(request)
    {:reply, result, state}
  end

  @doc false
  def handle_request({:register, registry, saga_id, key, value}) do
    Registry.register(registry, key, {saga_id, value})
  end

  def handle_request({:unregister, registry, key}) do
    Registry.unregister(registry, key)
  end

  def handle_request({:unregister_match, registry, key, pattern, guards}) do
    Registry.unregister_match(registry, key, pattern, guards)
  end

  def handle_request({:update_value, registry, key, callback}) do
    Registry.update_value(registry, key, fn {saga_id, value} -> {saga_id, callback.(value)} end)
  end
end
