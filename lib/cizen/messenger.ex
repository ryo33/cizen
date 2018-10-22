defmodule Cizen.Messenger do
  @moduledoc """
  Send messages.
  """

  alias Cizen.Channel
  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.EventFilter
  alias Cizen.EventFilterDispatcher
  alias Cizen.EventFilterDispatcher.PushEvent
  alias Cizen.Message
  alias Cizen.RegisterChannel
  alias Cizen.Saga
  alias Cizen.SagaID

  alias Cizen.SendMessage
  alias Cizen.SubscribeMessage

  defstruct []

  @behaviour Saga

  @doc "Subscribe message synchronously"
  @spec subscribe_message(SagaID.t(), module, EventFilter.t()) :: :ok
  def subscribe_message(saga_id, saga_module, event_filter) do
    task =
      Task.async(fn ->
        event =
          Event.new(saga_id, %SubscribeMessage{
            subscriber_saga_id: saga_id,
            subscriber_saga_module: saga_module,
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
  @spec register_channel(Channel.t(), EventFilter.t()) :: :ok
  def register_channel(channel, event_filter) do
    task =
      Task.async(fn ->
        event =
          Event.new(channel.saga_id, %RegisterChannel{
            channel: channel,
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
        subscriber_saga_id: saga_id,
        subscriber_saga_module: saga_module
      } = body

      meta = {saga_id, saga_module}
      EventFilterDispatcher.subscribe_as_proxy(id, saga_id, saga_module, body.event_filter, meta)

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
      saga_id = body.channel.saga_id
      saga_module = body.channel.saga_module
      meta = body.channel
      EventFilterDispatcher.subscribe_as_proxy(id, saga_id, saga_module, body.event_filter, meta)

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
          %EventFilterDispatcher.Subscription{meta: %Channel{}} -> :channels
          _ -> :others
        end)
      )

    channels =
      Enum.map(channels, fn %EventFilterDispatcher.Subscription{meta: channel} -> channel end)

    subscriptions
    |> Enum.each(fn subscription ->
      {subscriber_saga_id, subscriber_saga_module} = subscription.meta

      message = %Message{
        event: event,
        destination_saga_id: subscriber_saga_id,
        destination_saga_module: subscriber_saga_module
      }

      matched_channels =
        Enum.filter(channels, fn channel ->
          Channel.match?(channel, message)
        end)

      Dispatcher.dispatch(
        Event.new(id, %SendMessage{
          message: message,
          channels: matched_channels
        })
      )
    end)

    state
  end
end
