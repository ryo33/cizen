defmodule Citadel.Messenger do
  @moduledoc """
  Send messages.
  """

  alias Citadel.Channel
  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.EventFilter
  alias Citadel.EventFilterDispatcher
  alias Citadel.EventFilterDispatcher.PushEvent
  alias Citadel.Message
  alias Citadel.RegisterChannel
  alias Citadel.Saga
  alias Citadel.SagaID

  alias Citadel.SendMessage
  alias Citadel.SubscribeMessage

  defstruct []

  @behaviour Saga

  @doc "Subscribe message synchronously"
  @spec subscribe_message(SagaID.t(), module, EventFilter.t()) :: :ok
  def subscribe_message(saga_id, saga_module, event_filter) do
    task =
      Task.async(fn ->
        event =
          Event.new(%SubscribeMessage{
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
          Event.new(%RegisterChannel{
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
        Event.new(%SubscribeMessage.Subscribed{
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
        Event.new(%RegisterChannel.Registered{
          event_id: event_id
        })
      )
    end)

    state
  end

  @impl true
  def handle_event(
        _id,
        %Event{
          body: %PushEvent{
            event: event,
            subscriptions: subscriptions
          }
        },
        state
      ) do
    %{channels: channels, others: subscriptions} =
      Enum.group_by(subscriptions, fn
        %EventFilterDispatcher.Subscription{meta: %Channel{}} -> :channels
        _ -> :others
      end)

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
        Event.new(%SendMessage{
          message: message,
          channels: matched_channels
        })
      )
    end)

    state
  end
end
