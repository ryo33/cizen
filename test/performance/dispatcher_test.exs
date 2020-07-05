defmodule Cizen.Performance.DispatcherTest do
  use ExUnit.Case

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.Filter
  require Filter

  defmodule(TestEvent, do: defstruct([:num]))

  @tag timeout: 100_000
  test "log" do
    max_num = 100

    dispatch = fn num ->
      pid = self()
      Process.put(:count, 0)

      subscribers =
        1..num
        |> Enum.map(fn i ->
          rand = :rand.uniform(min(num, max_num))

          if rand == 1 do
            Process.put(:count, Process.get(:count) + 1)
          end

          spawn(fn ->
            Dispatcher.listen(Filter.new(fn %Event{body: %TestEvent{num: ^rand}} -> true end))
            send(pid, {:subscribed, i})

            receive do
              :stop -> :ok
            end
          end)
        end)

      for i <- 1..num do
        receive do
          {:subscribed, ^i} -> :ok
        end
      end

      spawn(fn ->
        Dispatcher.listen(Filter.new(fn %Event{body: %TestEvent{num: 1}} -> true end))
        send(pid, :subscribed)

        receive do
          %Event{body: %TestEvent{}} ->
            send(pid, :received)
        end
      end)

      receive do
        :subscribed -> :ok
      end

      {time, _} =
        :timer.tc(fn ->
          for _ <- 1..100_000 do
            Dispatcher.dispatch(Event.new(nil, %TestEvent{num: :rand.uniform(max_num) + 100}))
          end

          Dispatcher.dispatch(Event.new(nil, %TestEvent{num: 1}))

          receive do
            :received -> :ok
          end
        end)

      Enum.each(subscribers, &Process.exit(&1, :kill))

      links = Process.info(pid) |> Keyword.get(:links) |> length

      IO.puts(
        "#{Process.get(:count)} subscriber(s) #{inspect(time / 1000)} milliseconds (#{num} subscriber(s)) (#{
          links
        } links)"
      )

      time / 1000
    end

    bias = 0.5
    base_of_log = 1.01

    0..0
    |> Enum.map(fn e ->
      for _ <- 1..1 do
        num = :math.pow(10, e) |> round()
        time = dispatch.(num)
        # log_order = bias + :math.log(num) / :math.log(base_of_log)
        # assert time < log_order
      end
    end)

    # logs = Agent.get(:trace, & &1)
    # |> Enum.reverse()
    # |> Enum.reject(&is_nil(&1.event))

    # first_log = List.first(logs)

    # logs
    # |> Enum.with_index()
    # |> Enum.map(fn {log, i} -> Map.put(log, :index, i) end)
    # |> Enum.group_by(& &1.event.id)
    # |> Enum.sort_by(fn {_event_id, [log | _]} -> log.index end, :asc)
    # |> Enum.reduce(first_log.time, fn {_event_id, logs}, previous_event_time ->
    #   first_log = List.first(logs)
    #   IO.puts("#{inspect first_log.event.body}: #{NaiveDateTime.diff(first_log.time, previous_event_time, :microsecond)}")

    #   logs
    #   |> Enum.reduce(first_log.time, fn log, previous_time ->
    #     IO.puts("#{NaiveDateTime.diff(log.time, previous_time, :microsecond)}\t#{log.message}")
    #     log.time
    #   end)

    #   first_log.time
    # end)
  end
end
