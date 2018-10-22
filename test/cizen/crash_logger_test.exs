defmodule Cizen.CrashLoggerTest do
  use Cizen.SagaCase
  import ExUnit.CaptureLog
  alias Cizen.TestHelper

  alias Cizen.Dispatcher
  alias Cizen.Event

  defmodule(CrashTestEvent, do: defstruct([]))

  test "logs crashes" do
    saga_id =
      TestHelper.launch_test_saga(
        launch: fn _id, _state ->
          Dispatcher.listen_event_type(CrashTestEvent)
        end,
        handle_event: fn _id, %Event{body: body}, state ->
          case body do
            %CrashTestEvent{} ->
              raise "Crash!!!"

            _ ->
              state
          end
        end
      )

    output =
      capture_log(fn ->
        Dispatcher.dispatch(Event.new(nil, %CrashTestEvent{}))
        :timer.sleep(100)
        require Logger
        Logger.flush()
      end)

    assert output =~ "saga #{saga_id} is crashed"
    assert output =~ "(RuntimeError) Crash!!!"
    assert output =~ "test/cizen/crash_logger_test.exs:"
  end
end
