# Event

## Event Struct

A struct of `Cizen.Event` has the following four fields:

- `:id` an unique ID for the event.
- `:body` a struct.
- `:source_saga_id` a saga ID of the source of the event.
- `:source_saga` a saga struct the source of the event.

## Creating a Event

You can create an event by using `Cizen.Event.new/2` like this:

    event = Cizen.Event.new(nil, %PushMessage{to: "user A"})

The first argument is the source saga ID or `nil`, and the second argument is the event body.

## Dispatching Event

### With Dispatcher

    Cizen.Dispatcher.dispatch(
      Cizen.Event.new(nil, %PushMessage{to: "user A"})
    )

### With Dispatch Effect

    use Cizen.Effectful
    use Cizen.Effects

    handle fn id ->
      dispatched_event = perform id, %Dispatch{
        body: %PushMessage{to: "user A"}
      }
    end

## Requestive Event

You can make your event requestive. See `Cizen.Request.defresponse/3`.
