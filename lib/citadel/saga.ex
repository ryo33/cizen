defmodule Citadel.Saga do
  @moduledoc """
  The saga behaviour
  """

  @type t :: struct

  use GenServer

  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.Saga
  alias Citadel.SagaID
  alias Citadel.SagaRegistry

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

    import Citadel.EventBodyFilter

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
    defstruct([:id, :reason, :stacktrace])
  end

  @lazy_launch {__MODULE__, :lazy_launch}

  def lazy_launch, do: @lazy_launch

  @spec module(t) :: module
  def module(saga) do
    saga.__struct__
  end

  def launch(id, saga) do
    {:ok, _pid} =
      GenServer.start(__MODULE__, {id, saga}, name: {:via, Registry, {SagaRegistry, id}})
  end

  def unlaunch(id) do
    GenServer.stop({:via, Registry, {SagaRegistry, id}}, :shutdown)
  catch
    :exit, _ -> :ok
  after
    Dispatcher.dispatch(Event.new(%Unlaunched{id: id}))
  end

  def exit(id, reason, trace) do
    GenServer.stop({:via, Registry, {SagaRegistry, id}}, {:shutdown, {reason, trace}})
  end

  @impl true
  def init({id, saga}) do
    Dispatcher.listen_event_body(%Finish{id: id})
    module = Saga.module(saga)

    state =
      case module.init(id, saga) do
        {@lazy_launch, state} ->
          state

        state ->
          Dispatcher.dispatch(Event.new(%Launched{id: id}))
          state
      end

    {:ok, {id, module, state}}
  end

  @impl true
  def handle_info(%Event{body: %Finish{id: id}} = event, {id, module, state}) do
    {:stop, {:shutdown, event}, {id, module, state}}
  end

  @impl true
  def handle_info(%Event{} = event, {id, module, state}) do
    state = module.handle_event(id, event, state)
    {:noreply, {id, module, state}}
  rescue
    reason -> {:stop, {:shutdown, {reason, __STACKTRACE__}}, {id, module, state}}
  end

  @impl true
  def terminate(:shutdown, {_id, _module, _state}) do
    :shutdown
  end

  def terminate({:shutdown, %Event{}}, {id, _module, _state}) do
    Dispatcher.dispatch(Event.new(%Finished{id: id}))
    :shutdown
  end

  def terminate({:shutdown, {reason, trace}}, {id, _module, _state}) do
    Dispatcher.dispatch(Event.new(%Crashed{id: id, reason: reason, stacktrace: trace}))
    :shutdown
  end
end
