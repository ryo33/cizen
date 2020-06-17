defmodule Cizen.Performance.SubscriptionTest do
  use ExUnit.Case

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.Filter
  alias Cizen.Saga
  require Filter

  defmodule(TestEvent, do: defstruct([:num]))

  defmodule TestSaga do
    defstruct pid: nil, num: nil

    use Cizen.Automaton
    use Cizen.Effects

    def spawn(id, saga) do
      perform id, %Subscribe{
        event_filter: Filter.new(fn %Event{body: %TestEvent{num: num}} -> num == saga.num end)
      }

      saga
    end

    def yield(id, saga) do
      event = perform id, %Receive{}
      send(saga.pid, event)

      saga
    end
  end

  @tag timeout: 10000
  test "many subscriptions" do
    Dispatcher.listen(
      Filter.new(fn %Event{body: %Saga.Started{}, source_saga: %TestSaga{}} -> true end)
    )

    dispatch = fn num ->
      tasks =
        1..100
        |> Stream.cycle()
        |> Stream.map(fn i ->
          task =
            Task.async(fn ->
              receive do
                _ -> :ok
              end
            end)

          Saga.fork(%TestSaga{pid: task.pid, num: i})

          task
        end)
        |> Enum.take(num)

      for _ <- 1..num do
        receive do
          %Event{body: %Saga.Started{}, source_saga: %TestSaga{}} ->
            :ok
        end
      end

      1..100
      |> Stream.cycle()
      |> Stream.map(fn i ->
        Dispatcher.dispatch(Event.new(nil, %TestEvent{num: i}))
      end)
      |> Enum.take(num)

      tasks
      |> Enum.each(&Task.await(&1, 100_000))
    end

    {time, _} = :timer.tc(fn -> dispatch.(1) end)
    IO.puts(time / 1000)
    {time, _} = :timer.tc(fn -> dispatch.(10) end)
    IO.puts(time / 1000)
    {time, _} = :timer.tc(fn -> dispatch.(100) end)
    IO.puts(time / 1000)
    {time, _} = :timer.tc(fn -> dispatch.(1000) end)
    IO.puts(time / 1000)
    {time, _} = :timer.tc(fn -> dispatch.(10000) end)
    IO.puts(time / 1000)
  end
end
