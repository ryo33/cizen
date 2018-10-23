defmodule Cizen.Messenger do
  @moduledoc """
  Send messages.
  """

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.EventFilter
  alias Cizen.EventFilterDispatcher
  alias Cizen.EventFilterDispatcher.PushEvent
  alias Cizen.RegisterChannel
  alias Cizen.Saga
  alias Cizen.SagaID

  alias Cizen.Channel.FeedMessage
  alias Cizen.SendMessage
  alias Cizen.SubscribeMessage

  defstruct []

  @behaviour Saga

  @doc "Subscribe message synchronously"
  @spec subscribe_message(SagaID.t(), EventFilter.t()) :: :ok
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
  @spec register_channel(SagaID.t(), EventFilter.t()) :: :ok
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
    spawn_link(fn ->
      %SubscribeMessage{
        subscriber_saga_id: subscriber,
        event_filter: event_filter,
        lifetime_saga_id: lifetime
      } = body

      meta = {:subscriber, subscriber}

      if is_nil(lifetime) do
        EventFilterDispatcher.subscribe_as_proxy(id, subscriber, event_filter, meta)
      else
        EventFilterDispatcher.subscribe_as_proxy(id, lifetime, event_filter, meta)
      end

      Dispatcher.dispatch(
        Event.new(id, %SubscribeMessage.Subscribed{
          event_id: event_id
        })
      )
    end)

    state
  end

  @impl true
  def handle_event(id, %Event{id: event_id, body: %RegisterChannel{} = body}, state) do
    spawn_link(fn ->
      saga_id = body.channel_saga_id
      meta = :channel
      EventFilterDispatcher.subscribe_as_proxy(id, saga_id, body.event_filter, meta)

      Dispatcher.dispatch(
        Event.new(id, %RegisterChannel.Registered{
          event_id: event_id
        })
      )
    end)

    state
  end

  @impl true
  def handle_event(
        id,
        %Event{
          body: %PushEvent{
            event: event,
            subscriptions: subscriptions
          }
        },
        state
      ) do
    %{channels: channels, others: subscriptions} =
      Map.merge(
        %{channels: [], others: []},
        Enum.group_by(subscriptions, fn
          %EventFilterDispatcher.Subscription{meta: :channel} -> :channels
          _ -> :others
        end)
      )

    subscribers =
      subscriptions
      |> Enum.map(fn %EventFilterDispatcher.Subscription{meta: {:subscriber, subscriber}} ->
        subscriber
      end)

    if channels == [] do
      subscribers
      |> Enum.each(fn subscriber ->
        Dispatcher.dispatch(Event.new(id, %SendMessage{saga_id: subscriber, event: event}))
      end)
    else
      channels
      |> Enum.each(fn %EventFilterDispatcher.Subscription{subscriber_saga_id: channel} ->
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
