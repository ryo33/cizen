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

  @tag timeout: 5000
  test "log" do
    pid = self()

    dispatch = fn num ->
      1..num
      |> Enum.each(fn i ->
        spawn_link(fn ->
          Dispatcher.listen_event_body(%TestEvent{num: :rand.uniform()})
          send(pid, {:subscribed, i})
          :timer.sleep(100_000)
        end)
      end)

      for i <- 1..num do
        receive do
          {:subscribed, ^i} -> :ok
        end
      end

      spawn_link(fn ->
        Dispatcher.listen_event_body(%TestEvent{num: 0})
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
          Dispatcher.dispatch(Event.new(nil, %TestEvent{num: 0}))

          receive do
            :received -> :ok
          end
        end)

      IO.puts("#{num}: subscriber(s) in #{inspect(time / 1000)} milliseconds")
      time / 1000
    end

    bias = 0.5
    base_of_log = 1.01

    0..4
    |> Enum.map(fn e ->
      num = :math.pow(10, e) |> round()
      time = dispatch.(num)
      log_order = bias + :math.log(num) / :math.log(base_of_log)
      assert time < log_order
    end)
  end
end
