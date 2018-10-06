defmodule Citadel.Automaton do
  @moduledoc """
  A saga framework to create an automaton.
  """

  alias Citadel.Automaton.Effect
  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.EventFilter
  alias Citadel.EventFilterDispatcher
  alias Citadel.Message
  alias Citadel.Saga
  alias Citadel.SagaID

  alias Citadel.Automaton.PerformEffect
  alias Citadel.ReceiveMessage

  @callback yield(SagaID.t(), state :: term) :: state :: term

  @finish {__MODULE__, :finish}

  def finish, do: @finish

  defmacro __using__(_opts) do
    quote do
      alias Citadel.Automaton
      import Citadel.Automaton, only: [perform: 2]

      @behaviour Saga
      @behaviour Automaton

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

  defp yield(module, id, state) do
    case module.yield(id, state) do
      @finish ->
        Dispatcher.dispatch(Event.new(%Saga.Finish{id: id}))

      state ->
        yield(module, id, state)
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
        yield(module, id, saga)
      end)

    %{pid: pid, effect: nil, effect_state: nil, event_buffer: []}
  end

  def handle_event(
        id,
        %Event{
          body: %EventFilterDispatcher.PushEvent{
            event: %Event{
              body: %PerformEffect{
                effect: effect
              }
            }
          }
        },
        state
      ) do
    case Effect.init(id, effect) do
      {:resolve, value} ->
        send(state.pid, value)
        state

      effect_state ->
        state = %{state | effect: effect, effect_state: effect_state}
        {state, buffer} = feed_events(id, state, state.event_buffer)
        %{state | event_buffer: buffer}
    end
  end

  def handle_event(
        id,
        %Event{
          body: %ReceiveMessage{
            message: %Message{
              event: event
            }
          }
        },
        state
      ) do
    case state do
      %{effect: nil} ->
        append_to_buffer(state, event)

      state ->
        case feed_events(id, state, [event]) do
          {state, [event]} ->
            append_to_buffer(state, event)

          {state, []} ->
            state
        end
    end
  end

  defp append_to_buffer(state, event) do
    event_buffer = state.event_buffer ++ [event]
    %{state | event_buffer: event_buffer}
  end

  defp feed_events(__id, state, []), do: {state, []}

  defp feed_events(id, state, [event | tail]) do
    case Effect.handle_event(id, event, state.effect, state.effect_state) do
      {:resolve, value} ->
        send(state.pid, value)
        state = %{state | effect: nil}
        {state, tail}

      {:consume, effect_state} ->
        state = %{state | effect_state: effect_state}
        feed_events(id, state, tail)

      effect_state ->
        state = %{state | effect_state: effect_state}
        {state, tail} = feed_events(id, state, tail)
        {state, [event | tail]}
    end
  end
end
