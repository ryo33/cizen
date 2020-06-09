defmodule Cizen.Performance.FilterDispatcherTest do
  use ExUnit.Case

  alias Cizen.FilterDispatcher
  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.Filter
  require Filter

  defmodule(TestEvent, do: defstruct([:num]))

  @tag timeout: 5000
  test "log" do
    dispatch = fn num ->
      tasks =
        1..num
        |> Enum.map(fn i ->
          filter = Filter.new(fn %Event{body: %TestEvent{num: ^i}} -> true end)

          task =
            Task.async(fn ->
              receive do
                _ -> :ok
              end
            end)

          GenServer.cast(FilterDispatcher, {:listen, task.pid, filter, nil, []})

          # GenServer.cast(FilterDispatcher, {:listen, task.pid, filter})

          task
        end)

      1..num
      |> Enum.each(fn i ->
        Dispatcher.dispatch(Event.new(nil, %TestEvent{num: i}))
      end)

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
    IO.puts(time / 10000)
    {time, _} = :timer.tc(fn -> dispatch.(100_000) end)
    IO.puts(time / 10000)
  end
end
