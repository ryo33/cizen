defmodule Citadel.Saga do
  @moduledoc """
  The saga behaviour
  """

  use GenServer

  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.SagaID
  alias Citadel.SagaRegistry

  @type state :: any

  @doc false
  @callback init(SagaID.t(), state) :: state

  @doc false
  @callback handle_event(SagaID.t(), Event.t(), state) :: state

  defmodule Finish do
    @moduledoc "A event fired to finish"
    defstruct([:id])
  end

  defmodule Launched do
    @moduledoc "A event fired on launch"
    defstruct([:id])
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
    defstruct([:id, :reason])
  end

  def launch(id, module, state) do
    {:ok, _pid} =
      GenServer.start(__MODULE__, {id, module, state}, name: {:via, Registry, {SagaRegistry, id}})

    Dispatcher.dispatch(Event.new(%Launched{id: id}))
  end

  def unlaunch(id) do
    :ok = GenServer.stop({:via, Registry, {SagaRegistry, id}}, :shutdown)
  after
    Dispatcher.dispatch(Event.new(%Unlaunched{id: id}))
  end

  @impl true
  def init({id, module, state}) do
    Dispatcher.listen_event_body(%Finish{id: id})
    state = module.init(id, state)
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
    reason -> {:stop, {:shutdown, reason}, {id, module, state}}
  end

  @impl true
  def terminate(:shutdown, {_id, _module, _state}) do
    :shutdown
  end

  def terminate({:shutdown, %Event{}}, {id, _module, _state}) do
    Dispatcher.dispatch(Event.new(%Finished{id: id}))
    :shutdown
  end

  def terminate({:shutdown, reason}, {id, _module, _state}) do
    Dispatcher.dispatch(Event.new(%Crashed{id: id, reason: reason}))
    :shutdown
  end
end
