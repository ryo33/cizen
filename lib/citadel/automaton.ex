defmodule Citadel.Automaton do
  @moduledoc """
  A saga framework to create an automaton.
  """

  alias Citadel.Dispatcher
  alias Citadel.EffectHandler
  alias Citadel.Event
  alias Citadel.EventFilter
  alias Citadel.EventFilterDispatcher
  alias Citadel.Message
  alias Citadel.Saga
  alias Citadel.SagaID

  alias Citadel.Automaton.PerformEffect
  alias Citadel.ReceiveMessage

  @finish {__MODULE__, :finish}

  def finish, do: @finish

  @type finish :: {__MODULE__, :finish}
  @type state :: term

  @callback spawn(SagaID.t(), state) :: finish | state
  @callback yield(SagaID.t(), state) :: finish | state

  defmacro __using__(_opts) do
    quote do
      alias Citadel.Automaton
      import Citadel.Automaton, only: [perform: 2, finish: 0]
      require Citadel.EventFilter

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
  """
  defmacro perform(id, effect) do
    quote do
      Dispatcher.dispatch(
        Event.new(%PerformEffect{effect: unquote(effect)}, unquote(id), __MODULE__)
      )

      receive do
        response -> response
      end
    end
  end

  defp do_yield(module, id, state) do
    case state do
      @finish ->
        Dispatcher.dispatch(Event.new(%Saga.Finish{id: id}))

      state ->
        state = module.yield(id, state)
        do_yield(module, id, state)
    end
  end

  def init(id, saga) do
    EventFilterDispatcher.subscribe(id, __MODULE__, %EventFilter{
      source_saga_id: id,
      event_type: PerformEffect
    })

    module = Saga.module(saga)

    pid =
      spawn_link(fn ->
        state = module.spawn(id, saga)
        Dispatcher.dispatch(Event.new(%Saga.Launched{id: id}))
        do_yield(module, id, state)
      end)

    handler_state = EffectHandler.init(id)

    {Saga.lazy_launch(), {pid, handler_state}}
  end

  def handle_event(
        _id,
        %Event{
          body: %EventFilterDispatcher.PushEvent{
            event: %Event{
              body: %PerformEffect{
                effect: effect
              }
            }
          }
        },
        {pid, handler}
      ) do
    handle_result(pid, EffectHandler.perform_effect(handler, effect))
  end

  def handle_event(
        _id,
        %Event{
          body: %ReceiveMessage{
            message: %Message{
              event: event
            }
          }
        },
        state
      ) do
    feed_event(state, event)
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
