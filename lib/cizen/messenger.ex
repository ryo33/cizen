defmodule Cizen.Messenger do
  @moduledoc """
  Send messages.
  """

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.Filter
  alias Cizen.FilterDispatcher
  alias Cizen.FilterDispatcher.PushEvent
  alias Cizen.RegisterChannel
  alias Cizen.Saga
  alias Cizen.SagaID

  alias Cizen.Channel.FeedMessage
  alias Cizen.SendMessage
  alias Cizen.SubscribeMessage

  defstruct []

  use Saga

  @doc "Subscribe message synchronously"
  @spec subscribe_message(SagaID.t(), Filter.t()) :: :ok
  def subscribe_message(saga_id, event_filter) do
    task =
      Task.async(fn ->
        event =
          Event.new(saga_id, %SubscribeMessage{
            subscriber_saga_id: saga_id,
            event_filter: event_filter
          })

        Dispatcher.listen_event_body(%SubscribeMessage.Subscribed{
          event_id: event.id
        })

        Dispatcher.dispatch(event)

        receive do
          %Event{body: %SubscribeMessage.Subscribed{}} -> :ok
        end
      end)

    Task.await(task, 100)
  end

  @doc "Register channel synchronously"
  @spec register_channel(SagaID.t(), Filter.t()) :: :ok
  def register_channel(channel_id, event_filter) do
    task =
      Task.async(fn ->
        event =
          Event.new(channel_id, %RegisterChannel{
            channel_saga_id: channel_id,
            event_filter: event_filter
          })

        Dispatcher.listen_event_body(%RegisterChannel.Registered{
          event_id: event.id
        })

        Dispatcher.dispatch(event)

        receive do
          %Event{body: %RegisterChannel.Registered{}} -> :ok
        end
      end)

    Task.await(task, 100)
  end

  @impl true
  def init(_id, saga) do
    Dispatcher.listen_event_type(SubscribeMessage)
    Dispatcher.listen_event_type(RegisterChannel)
    saga
  end

  @impl true
  def handle_event(id, %Event{id: event_id, body: %SubscribeMessage{} = body}, state) do
    %SubscribeMessage{
      subscriber_saga_id: subscriber,
      event_filter: event_filter,
      lifetime_saga_id: lifetime
    } = body

    meta = {:subscriber, subscriber}

    if is_nil(lifetime) do
      case Saga.get_pid(subscriber) do
        {:ok, pid} ->
          lifetimes = [pid]
          FilterDispatcher.listen_with_meta(event_filter, meta, lifetimes)

        _ ->
          :ok
      end
    else
      with {:ok, s_pid} <- Saga.get_pid(subscriber),
           {:ok, l_pid} <- Saga.get_pid(lifetime) do
        lifetimes = [s_pid, l_pid]
        FilterDispatcher.listen_with_meta(event_filter, meta, lifetimes)
      else
        _ -> :ok
      end
    end

    Dispatcher.dispatch(
      Event.new(id, %SubscribeMessage.Subscribed{
        event_id: event_id
      })
    )

    state
  end

  @impl true
  def handle_event(id, %Event{id: event_id, body: %RegisterChannel{} = body}, state) do
    channel = body.channel_saga_id
    meta = {:channel, channel}

    case Saga.get_pid(channel) do
      {:ok, pid} ->
        lifetimes = [pid]
        FilterDispatcher.listen_with_meta(body.event_filter, meta, lifetimes)

      _ ->
        :ok
    end

    Dispatcher.dispatch(
      Event.new(id, %RegisterChannel.Registered{
        event_id: event_id
      })
    )

    state
  end

  @impl true
  def handle_event(id, %Event{body: %PushEvent{event: event, metas: metas}}, state) do
    %{channels: channels, others: subscribers} =
      metas
      |> Enum.group_by(
        fn
          {:channel, _} -> :channels
          _ -> :others
        end,
        fn {_, saga_id} -> saga_id end
      )
      |> Enum.into(%{channels: [], others: []})

    if channels == [] do
      subscribers
      |> Enum.each(fn subscriber ->
        Dispatcher.dispatch(Event.new(id, %SendMessage{saga_id: subscriber, event: event}))
      end)
    else
      channels
      |> Enum.each(fn channel ->
        Dispatcher.dispatch(
          Event.new(id, %FeedMessage{
            channel_saga_id: channel,
            event: event,
            subscribers: subscribers
          })
        )
      end)
    end

    state
  end
end
