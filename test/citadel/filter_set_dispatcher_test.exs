defmodule Citadel.FilterSetDispatcherTest do
  use ExUnit.Case

  import Citadel.TestHelper, only: [launch_test_saga: 1]

  alias Citadel.Event
  alias Citadel.Filter
  alias Citadel.FilterSet
  alias Citadel.FilterSetSubscribe
  alias Citadel.FilterSetSubscribed
  import Citadel.Dispatcher, only: [dispatch: 1, listen_event_type: 1]

  defmodule(TestEvent, do: defstruct([:value_a, :value_b]))

  defmodule TestFilterA do
    @behaviour Filter
    @impl true
    def test(%Event{body: %TestEvent{value_a: value}}, opts), do: value == opts
    def test(_, _), do: false
  end

  defmodule TestFilterB do
    @behaviour Filter
    @impl true
    def test(%Event{body: %TestEvent{value_b: value}}, opts), do: value == opts
    def test(_, _), do: false
  end

  test "FilterSetSubscribe event" do
    listen_event_type(FilterSetSubscribed)
    pid = self()
    saga_id = launch_test_saga(handle_event: fn _id, event, _state -> send(pid, event) end)
    filter_set = FilterSet.new([Filter.new(TestFilterA, :a), Filter.new(TestFilterB, :b)])

    dispatch(
      Event.new(%FilterSetSubscribe{
        saga_id: saga_id,
        filter_set: filter_set
      })
    )

    receive do
      %Event{body: %FilterSetSubscribed{}} -> :ok
    after
      1000 -> :ok
    end

    dispatch(Event.new(%TestEvent{value_a: :a, value_b: :a}))
    dispatch(Event.new(%TestEvent{value_a: :a, value_b: :b}))
    dispatch(Event.new(%TestEvent{value_a: :b, value_b: :a}))
    dispatch(Event.new(%TestEvent{value_a: :b, value_b: :b}))
    refute_receive %Event{body: %TestEvent{value_a: :a, value_b: :a}}
    assert_receive %Event{body: %TestEvent{value_a: :a, value_b: :b}}
    refute_receive %Event{body: %TestEvent{value_a: :b, value_b: :a}}
    refute_receive %Event{body: %TestEvent{value_a: :b, value_b: :b}}
  end

  test "dispatches for subscriber" do
    listen_event_type(FilterSetSubscribed)
    pid = self()
    saga_a = launch_test_saga(handle_event: fn _id, event, _state -> send(pid, {:a, event}) end)
    saga_b = launch_test_saga(handle_event: fn _id, event, _state -> send(pid, {:b, event}) end)
    filter_set_a = FilterSet.new([Filter.new(TestFilterA, :a), Filter.new(TestFilterB, :b)])
    filter_set_b = FilterSet.new([Filter.new(TestFilterA, :a), Filter.new(TestFilterB, :a)])

    dispatch(
      Event.new(%FilterSetSubscribe{
        saga_id: saga_a,
        filter_set: filter_set_a
      })
    )

    dispatch(
      Event.new(%FilterSetSubscribe{
        saga_id: saga_b,
        filter_set: filter_set_b
      })
    )

    receive do
      %Event{body: %FilterSetSubscribed{}} -> :ok
    after
      1000 -> :ok
    end

    receive do
      %Event{body: %FilterSetSubscribed{}} -> :ok
    after
      1000 -> :ok
    end

    dispatch(Event.new(%TestEvent{value_a: :a, value_b: :b}))
    assert_receive {:a, %Event{body: %TestEvent{value_a: :a, value_b: :b}}}
    refute_receive {:b, _}
  end
end
