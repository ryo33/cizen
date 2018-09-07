defmodule Citadel.Saga do
  @moduledoc """
  The saga behaviour
  """

  use GenServer

  import Citadel.Dispatcher, only: [listen_event_body: 1, dispatch: 1]
  alias Citadel.Event
  alias Citadel.SagaID
  alias Citadel.SagaRegistry

  @type state :: any

  @doc false
  @callback launch(SagaID.t(), state) :: state

  @doc false
  @callback yield(SagaID.t(), Event.t(), state) :: state

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

    dispatch(Event.new(%Launched{id: id}))
  end

  def unlaunch(id) do
    :ok = GenServer.stop({:via, Registry, {SagaRegistry, id}}, :shutdown)
    dispatch(Event.new(%Unlaunched{id: id}))
  end

  @impl true
  def init({id, module, state}) do
    state = module.launch(id, state)
    listen_event_body(%Finish{id: id})
    {:ok, {id, module, state}}
  end

  @impl true
  def handle_info(%Event{body: %Finish{id: id}} = event, {id, module, state}) do
    {:stop, {:shutdown, event}, {id, module, state}}
  end

  @impl true
  def handle_info(%Event{} = event, {id, module, state}) do
    state = module.yield(id, event, state)
    {:noreply, {id, module, state}}
  end

  @impl true
  def terminate(:shutdown, {_id, _module, _state}) do
    :shutdown
  end

  def terminate({:shutdown, %Event{}}, {id, _module, _state}) do
    dispatch(Event.new(%Finished{id: id}))
    :shutdown
  end

  def terminate(reason, {id, _module, _state}) do
    dispatch(Event.new(%Crashed{id: id, reason: reason}))
    :shutdown
  end
end
