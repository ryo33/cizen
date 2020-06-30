defmodule Cizen.Performance.DispatcherTest do
  use ExUnit.Case

  alias Cizen.Dispatcher
  alias Cizen.Event
  alias Cizen.Filter
  require Filter

  defmodule(TestEvent, do: defstruct([:num]))

  defp wait_until_receive(message) do
    receive do
      ^message -> :ok
    after
      100 -> flunk("#{message} timeout")
    end
  end

  @tag timeout: 200_000
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
            Dispatcher.listen_event_body(%TestEvent{num: rand})
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
        Dispatcher.listen_event_body(%TestEvent{num: 1})
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

    0..4
    |> Enum.map(fn e ->
      for _ <- 1..10 do
        Task.async(fn ->
          num = :math.pow(10, e) |> round()
          time = dispatch.(num)
          # log_order = bias + :math.log(num) / :math.log(base_of_log)
          # assert time < log_order
        end)
        |> Task.await()
      end
    end)

    # alias Cizen.Dispatcher.Node

    # Node.expand(Node)
    # |> IO.inspect()

    4..0
    |> Enum.map(fn e ->
      for _ <- 1..10 do
        Task.async(fn ->
          num = :math.pow(10, e) |> round()
          time = dispatch.(num)
          # log_order = bias + :math.log(num) / :math.log(base_of_log)
          # assert time < log_order
        end)
        |> Task.await()

        :timer.sleep(1000)
      end
    end)

    processes = :erlang.processes()
    IO.puts(length(processes))

    processes
    |> Enum.map(&Process.info(&1))
    |> Enum.group_by(fn info ->
      dict = info[:dictionary]

      if dict do
        case dict[:"$initial_call"] do
          {mod, _, _} -> mod
          _ -> nil
        end
      end
    end)
    |> Enum.map(fn {key, value} -> {inspect(key), length(value), nil} end)
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(30)
    |> IO.inspect()
  end
end
