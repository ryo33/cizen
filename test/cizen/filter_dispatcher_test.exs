defmodule Cizen.FilterDispatcherTest do
  use Cizen.SagaCase

  alias Cizen.TestHelper
  import Cizen.TestHelper, only: [launch_test_saga: 0, launch_test_saga: 1, assert_condition: 2]

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.Filter
  alias Cizen.FilterDispatcher
  alias Cizen.FilterDispatcher.PushEvent
  alias Cizen.Saga
  alias Cizen.SagaID

  defmodule(TestEvent, do: defstruct([:value]))

  test "listen event" do
    pid = self()
    source_saga_id = launch_test_saga()

    event_filter = Filter.new(fn %Event{source_saga_id: value} -> value == source_saga_id end)

    launch_test_saga(
      launch: fn _, _ ->
        FilterDispatcher.listen(event_filter)
      end,
      handle_event: fn _id, event, _state -> send(pid, event) end
    )

    Dispatcher.dispatch(Event.new(source_saga_id, %TestEvent{value: :a}))
    Dispatcher.dispatch(Event.new(launch_test_saga(), %TestEvent{value: :b}))

    assert_receive %Event{body: %TestEvent{value: :a}}
    refute_receive %Event{body: %TestEvent{value: :b}}
  end

  test "dispatches for subscriber" do
    pid = self()
    source_saga_id = launch_test_saga()

    launch_test_saga(
      launch: fn _, _ ->
        FilterDispatcher.listen(
          Filter.new(fn %Event{source_saga_id: value} -> value == source_saga_id end)
        )
      end,
      handle_event: fn _id, event, _state -> send(pid, {:a, event}) end
    )

    launch_test_saga(
      launch: fn _, _ ->
        FilterDispatcher.listen(
          Filter.new(fn %Event{source_saga_id: value} -> value == SagaID.new() end)
        )
      end,
      handle_event: fn _id, event, _state -> send(pid, {:b, event}) end
    )

    Dispatcher.dispatch(Event.new(source_saga_id, %TestEvent{value: :a}))

    assert_receive {:a,
                    %Event{
                      body: %TestEvent{
                        value: :a
                      }
                    }}

    refute_receive {:b, _}
  end

  test "dispatches once for multiple subscriptions" do
    pid = self()
    source_saga_id = launch_test_saga()

    launch_test_saga(
      launch: fn _, _ ->
        FilterDispatcher.listen(
          Filter.new(fn %Event{source_saga_id: value} -> value == source_saga_id end)
        )

        FilterDispatcher.listen(
          Filter.new(fn %Event{source_saga_id: value} -> value == source_saga_id end)
        )
      end,
      handle_event: fn _id, event, _state -> send(pid, event) end
    )

    Dispatcher.dispatch(Event.new(source_saga_id, %TestEvent{value: :a}))

    assert_receive %Event{body: %TestEvent{value: :a}}
    refute_receive %Event{body: %TestEvent{value: :a}}
  end

  test "listens with meta values" do
    pid = self()
    source_saga_id = launch_test_saga()

    launch_test_saga(
      launch: fn _, _ ->
        FilterDispatcher.listen_with_meta(
          Filter.new(fn %Event{source_saga_id: value} -> value == source_saga_id end),
          :a
        )

        FilterDispatcher.listen_with_meta(
          Filter.new(fn %Event{source_saga_id: value} -> value == source_saga_id end),
          :b
        )
      end,
      handle_event: fn _id, event, _state -> send(pid, event) end
    )

    Dispatcher.dispatch(Event.new(source_saga_id, %TestEvent{value: :a}))

    received = assert_receive %Event{body: %PushEvent{event: %Event{body: %TestEvent{value: :a}}}}
    metas = received.body.metas
    assert length(metas) == 2
    assert :a in metas
    assert :b in metas
    refute_receive %Event{}
  end

  test "dispatches PushEvent event" do
    source_saga_id = launch_test_saga()

    launch_test_saga(
      launch: fn _, _ ->
        FilterDispatcher.listen_with_meta(
          Filter.new(fn %Event{source_saga_id: value} -> value == source_saga_id end),
          :a
        )

        FilterDispatcher.listen_with_meta(
          Filter.new(fn %Event{source_saga_id: value} -> value == source_saga_id end),
          :b
        )
      end
    )

    Dispatcher.listen_event_type(PushEvent)

    Dispatcher.dispatch(Event.new(source_saga_id, %TestEvent{value: :a}))

    received = assert_receive %Event{body: %PushEvent{event: %Event{body: %TestEvent{value: :a}}}}
    metas = received.body.metas
    assert length(metas) == 2
    assert :a in metas
    assert :b in metas
    refute_receive %Event{}
  end

  test "remove the subscription when the saga finishes" do
    old_state = :sys.get_state(FilterDispatcher)

    pid = self()
    source_saga_id = launch_test_saga()

    saga_id =
      launch_test_saga(
        launch: fn _, _ ->
          FilterDispatcher.listen(
            Filter.new(fn %Event{source_saga_id: value, body: %TestEvent{}} ->
              value == source_saga_id
            end)
          )
        end,
        handle_event: fn _id, event, _state -> send(pid, event) end
      )

    TestHelper.ensure_finished(saga_id)

    assert_condition(100, :sys.get_state(FilterDispatcher) == old_state)

    Dispatcher.dispatch(Event.new(source_saga_id, %TestEvent{value: :a}))

    refute_receive %Event{}
  end

  test "removes the subscription when the lifetime saga finishes" do
    old_state = :sys.get_state(FilterDispatcher)

    pid = self()
    source_saga_id = launch_test_saga()
    lifetime_saga = launch_test_saga()
    {:ok, lifetime} = Saga.get_pid(lifetime_saga)
    lifetime2_saga = launch_test_saga()
    {:ok, lifetime2} = Saga.get_pid(lifetime2_saga)

    launch_test_saga(
      launch: fn _, _ ->
        FilterDispatcher.listen(
          Filter.new(fn %Event{source_saga_id: value, body: %TestEvent{}} ->
            value == source_saga_id
          end),
          [lifetime, lifetime2]
        )
      end,
      handle_event: fn _id, event, _state -> send(pid, event) end
    )

    TestHelper.ensure_finished(lifetime_saga)

    assert_condition(1000, :sys.get_state(FilterDispatcher) == old_state)

    Dispatcher.dispatch(Event.new(source_saga_id, %TestEvent{value: :a}))

    refute_receive %Event{body: %TestEvent{}}
  end
end
