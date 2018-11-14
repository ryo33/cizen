defmodule Cizen.Automaton do
  @moduledoc """
  A saga framework to create an automaton.
  """

  alias Cizen.Dispatcher
  alias Cizen.EffectHandler
  alias Cizen.Event
  alias Cizen.Saga
  alias Cizen.SagaID

  alias Cizen.Automaton.PerformEffect

  @finish {__MODULE__, :finish}

  def finish, do: @finish

  @type finish :: {__MODULE__, :finish}
  @type state :: term

  @doc """
  Invoked when the automaton is spawned.
  Saga.Started event will be dispatched after this callback.

  Returned value will be used as the next state to pass `yield/2` callback.
  Returning Automaton.finish() will cause the automaton to finish.

  If not defined, default implementation is used,
  and it passes the given saga struct to `yield/2` callback.
  """
  @callback spawn(SagaID.t(), Saga.t()) :: finish | state

  @doc """
  Invoked when last `spawn/2` or yield/2 callback returns a next state.

  Returned value will be used as the next state to pass `yield/2` callback.
  Returning `Automaton.finish()` will cause the automaton to finish.

  If not defined, default implementation is used,
  and it returns `Automaton.finish()`.
  """
  @callback yield(SagaID.t(), state) :: finish | state

  defmacro __using__(_opts) do
    quote do
      alias Cizen.Automaton
      import Cizen.Automaton, only: [perform: 2, finish: 0]
      require Cizen.Filter

      @behaviour Saga
      @behaviour Automaton

      @impl Automaton
      def spawn(_id, struct) do
        struct
      end

      @impl Automaton
      def yield(_id, _state) do
        finish()
      end

      defoverridable spawn: 2, yield: 2

      @impl Saga
      def init(id, struct) do
        Automaton.init(id, struct)
      end

      @impl Saga
      def handle_event(id, event, state) do
        Automaton.handle_event(id, event, state)
      end
    end
  end

  @doc """
  Performs an effect.

  `perform/2` blocks the current block until the effect is resolved,
  and returns the result of the effect.

  Note that `perform/2` does not work only on the current process.
  """
  def perform(id, effect) do
    event = Event.new(id, %PerformEffect{handler: id, effect: effect})
    Dispatcher.dispatch(event)
    {:ok, pid} = Saga.get_pid(id)
    send(pid, event)

    receive do
      response -> response
    end
  end

  defp do_yield(module, id, state) do
    case state do
      @finish ->
        Dispatcher.dispatch(Event.new(id, %Saga.Finish{id: id}))

      state ->
        state = module.yield(id, state)
        do_yield(module, id, state)
    end
  end

  def init(id, saga) do
    module = Saga.module(saga)

    pid =
      spawn_link(fn ->
        try do
          state = module.spawn(id, saga)
          Dispatcher.dispatch(Event.new(id, %Saga.Started{id: id}))
          do_yield(module, id, state)
        rescue
          reason -> Saga.exit(id, reason, __STACKTRACE__)
        end
      end)

    handler_state = EffectHandler.init(id)

    {Saga.lazy_launch(), {pid, handler_state}}
  end

  def handle_event(_id, %Event{body: %PerformEffect{effect: effect}}, {pid, handler}) do
    handle_result(pid, EffectHandler.perform_effect(handler, effect))
  end

  def handle_event(_id, event, state) do
    feed_event(state, event)
  end

  defp feed_event({pid, handler}, event) do
    handle_result(pid, EffectHandler.feed_event(handler, event))
  end

  defp handle_result(pid, {:resolve, value, state}) do
    send(pid, value)
    {pid, state}
  end

  defp handle_result(pid, state) do
    {pid, state}
  end
end
