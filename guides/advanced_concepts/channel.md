# Channel

Channel is the mechanism that guarantees high extensibility for Cizen application.
The idea is that a channel interupting messages and rejects it or dispatches other events.
Messages are dispatched events for subscribers which use `Cizen.Messenger` for subscription.
You would say, "What's Messenger? I don't know." Don't worry! You already use it for your subscriptions through `Cizen.Effects.Subscribe` effect.

## Define Channel

A channel is a saga, and its difference from other sagas is only the way of subscription, and `Cizen.RegisterChannel` is an event for that.
After the channel is registered, events are interupted and the channel saga receives `Cizen.Channel.FeedMessage` events.
To dispatch the interupted events to subscribers, you can dispatch `Cizen.Channel.EmitMessage` event.

## Channel Chaining

You can also interupt `Cizen.Channel.EmitMessage` to chain channels.
