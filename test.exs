defmodule A, do: defstruct([:a])

defmodule B do
  alias Cizen.{Dispatcher, Event, Filter}

  require Filter

  def run do
    :ets.delete_all_objects(Dispatcher)
    pid = self()
    task_count = 8
    event_count = 1000

    tasks =
      1..task_count
      |> Enum.map(
        &fn ->
          Dispatcher.listen(Filter.new(fn %Event{body: %A{a: ^&1}} -> true end))
          send pid, :listened
          for _ <- 1..event_count do
            receive do
              _ -> :ok
            end
          end
        end
      )
      |> Enum.map(&Task.async(&1))

    for _ <- 1..task_count do
      receive do
        :listened -> :ok
      end
    end

    1..task_count
    |> Enum.shuffle()
    |> Enum.flat_map(&(Stream.cycle([&1]) |> Enum.take(event_count)))
    |> Enum.each(
      &spawn(fn ->
        Dispatcher.dispatch(Event.new(nil, %A{a: &1}))
      end)
    )

    tasks |> Enum.map(&Task.await(&1, :infinity))

    :ets.tab2list(Cizen.Dispatcher)
    |> Enum.group_by(fn {{event, _label}, _time} -> event end, fn {{_event, label}, time} ->
      {time, label}
    end)
    |> Enum.map(fn {_event, logs} ->
      logs
      |> Enum.sort_by(&elem(&1, 0), :desc)
      |> Enum.map_reduce(nil, fn {time, label}, prev_time ->
        delta_time = if is_nil(prev_time), do: 0, else: prev_time - time
        {{label, delta_time}, time}
      end)
      |> elem(0)
      |> Enum.reverse()
    end)
    |> Enum.zip()
    |> Enum.map(fn list ->
      list = list |> Tuple.to_list()
      [{label, _} | _] = list

      sum = list
      |> Enum.map(fn {^label, time} -> time end)
      |> Enum.sum()

      {sum / 1000, label}
    end)
    # |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.each(&IO.inspect(&1, width: 200))
  end
end

time = 1..10
|> Enum.map(fn _ ->
{time, _} = :timer.tc(fn -> B.run() end)
IO.puts("#{time / 1_000_000}ms")
:timer.sleep(1000)
time
end)
|> Enum.sum()

IO.puts("#{time/10/1_000_000}ms")
