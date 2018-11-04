# Filter

`Cizen.Filter` is a module to filter events for subscriptions.

## All Events

The following filter matches with all events.

    require Cizen.Filter

    filter = Cizen.Filter.new(fn _ -> true end)

## Specific Type of Events

When you want to create a filter which matches only `YourEvent`, you can write:

    require Cizen.Filter

    filter = Cizen.Filter.new(
      fn %Event{body: %YourEvent{}} -> true end
    )

## Compose Filters

Compose filters by using `Cizen.Filter.match?/2` in the `Cizen.Filter.new/1` like this:

    require Cizen.Filter

    source_saga_filter = Cizen.Filter.new(fn %YourSaga{} -> true end)
    body_filter = Cizen.Filter.new(fn %YourEvent{some_field: value} ->
      value == "some value"
    end)
    composed_filter = Cizen.Filter.new(
      fn %Event{source_saga: source_saga, body: body} ->
        Cizen.Filter.match?(
          source_saga_filter, source_saga
        ) and Cizen.Filter.match?(
          body_filter, body
        )
      end
    )
