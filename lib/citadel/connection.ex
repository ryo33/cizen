defmodule Citadel.Connection do
  @moduledoc """
  An saga to connect two sagas by given channels.
  """

  alias Citadel.Channel
  alias Citadel.Channel.EmitMessage
  alias Citadel.Channel.FeedMessage
  alias Citadel.Channel.RejectMessage
  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.ReceiveMessage
  alias Citadel.Saga
  alias Citadel.SagaRegistry

  alias Citadel.EventBodyFilter
  alias Citadel.EventBodyFilterSet
  alias Citadel.EventFilter
  alias Citadel.EventFilterDispatcher
  alias Citadel.EventFilterDispatcher.PushEvent

  @behaviour Saga

  defp feed_event_to_channels(next_channels, id, state) do
    %{message: message, active_channels: active_channels} = state

    if Enum.empty?(next_channels) do
      Dispatcher.dispatch(
        Event.new(%ReceiveMessage{
          message: message
        })
      )

      Dispatcher.dispatch(
        Event.new(%Saga.Finish{
          id: id
        })
      )

      %{state | closed: true, active_channels: active_channels}
    else
      Enum.each(next_channels, fn channel ->
        Dispatcher.dispatch(
          Event.new(%FeedMessage{
            connection_id: id,
            channel: channel,
            message: message
          })
        )
      end)

      active_channels =
        Enum.reduce(
          next_channels,
          active_channels,
          fn channel, active_channels ->
            MapSet.put(active_channels, channel)
          end
        )

      %{state | active_channels: active_channels}
    end
  end

  @impl true
  def init(id, {message, channels}) do
    if Enum.any?(channels, fn %Channel{saga_id: saga_id} ->
         :error == SagaRegistry.resolve_id(saga_id)
       end) do
      Dispatcher.dispatch(
        Event.new(%Saga.Finish{
          id: id
        })
      )
    end

    Enum.each(channels, fn %Channel{saga_id: saga_id} ->
      Dispatcher.listen_event_body(%Saga.Finish{id: saga_id})
      Dispatcher.listen_event_body(%Saga.Finished{id: saga_id})
      Dispatcher.listen_event_body(%Saga.Crashed{id: saga_id})
    end)

    EventFilterDispatcher.subscribe(id, __MODULE__, %EventFilter{
      event_type: EmitMessage,
      event_body_filter_set:
        EventBodyFilterSet.new([
          EventBodyFilter.new(EmitMessage.ConnectionIDFilter, id)
        ])
    })

    EventFilterDispatcher.subscribe(id, __MODULE__, %EventFilter{
      event_type: RejectMessage,
      event_body_filter_set:
        EventBodyFilterSet.new([
          EventBodyFilter.new(RejectMessage.ConnectionIDFilter, id)
        ])
    })

    active_channels =
      channels
      |> Enum.filter(fn
        %Channel{previous_channel_module: nil} -> true
        _ -> false
      end)

    state = %{
      message: message,
      channels: channels,
      active_channels: MapSet.new(active_channels),
      closed: false
    }

    feed_event_to_channels(active_channels, id, state)
  end

  @impl true
  def handle_event(_id, %Event{body: %PushEvent{}}, %{closed: true} = state) do
    # Do nothing if closed
    state
  end

  def handle_event(
        id,
        %Event{
          body: %PushEvent{
            event: %Event{body: %EmitMessage{connection_id: id} = emit}
          }
        },
        %{closed: false} = state
      ) do
    %{channels: channels, active_channels: active_channels} = state
    state = %{state | active_channels: MapSet.delete(active_channels, emit.channel)}

    next_channels =
      channels
      |> Enum.filter(fn next ->
        Channel.adjoin?(emit.channel, next)
      end)

    feed_event_to_channels(next_channels, id, state)
  end

  @impl true
  def handle_event(
        id,
        %Event{
          body: %PushEvent{
            event: %Event{body: %RejectMessage{connection_id: id} = reject}
          }
        },
        state
      ) do
    %{active_channels: active_channels} = state
    active_channels = MapSet.delete(active_channels, reject.channel)

    if MapSet.size(active_channels) == 0 do
      Dispatcher.dispatch(
        Event.new(%Saga.Finish{
          id: id
        })
      )

      %{state | closed: true, active_channels: active_channels}
    else
      %{state | active_channels: active_channels}
    end
  end

  @impl true
  def handle_event(id, %Event{body: %Saga.Finish{}}, state) do
    Dispatcher.dispatch(
      Event.new(%Saga.Finish{
        id: id
      })
    )

    %{state | closed: true}
  end

  @impl true
  def handle_event(id, %Event{body: %Saga.Finished{}}, state) do
    Dispatcher.dispatch(
      Event.new(%Saga.Finish{
        id: id
      })
    )

    %{state | closed: true}
  end

  @impl true
  def handle_event(id, %Event{body: %Saga.Crashed{}}, state) do
    Dispatcher.dispatch(
      Event.new(%Saga.Finish{
        id: id
      })
    )

    %{state | closed: true}
  end
end
