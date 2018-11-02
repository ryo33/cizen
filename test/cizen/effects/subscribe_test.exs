defmodule Cizen.Effects.SubscribeTest do
  use Cizen.SagaCase
  alias Cizen.TestHelper

  alias Cizen.Automaton
  alias Cizen.Dispatcher
  alias Cizen.Effects.{Receive, Subscribe}
  alias Cizen.Event
  alias Cizen.Filter
  alias Cizen.SagaID

  alias Cizen.StartSaga
  alias Cizen.SubscribeMessage

  defmodule(TestEvent, do: defstruct([:value]))

  describe "Subscribe" do
    test "dispatches Subscribe event" do
      Dispatcher.listen_event_type(SubscribeMessage)

      event_filter = Filter.new(fn %Event{body: %TestEvent{}} -> true end)

      id =
        assert_handle(fn id ->
          perform id, %Subscribe{
            event_filter: event_filter
          }

          id
        end)

      assert_receive %Event{
        body: %SubscribeMessage{
          subscriber_saga_id: ^id,
          event_filter: ^event_filter,
          lifetime_saga_id: nil
        }
      }
    end

    test "dispatches Subscribe event with lifetime" do
      Dispatcher.listen_event_type(SubscribeMessage)

      event_filter = Filter.new(fn %Event{body: %TestEvent{}} -> true end)

      lifetime = TestHelper.launch_test_saga()

      id =
        assert_handle(fn id ->
          perform id, %Subscribe{
            event_filter: event_filter,
            lifetime_saga_id: lifetime
          }

          id
        end)

      assert_receive %Event{
        body: %SubscribeMessage{
          subscriber_saga_id: ^id,
          event_filter: ^event_filter,
          lifetime_saga_id: ^lifetime
        }
      }
    end

    defmodule TestAutomaton do
      use Automaton

      defstruct [:pid]

      @impl true
      def yield(id, %__MODULE__{pid: pid}) do
        send(
          pid,
          perform(id, %Subscribe{
            event_filter: Filter.new(fn %Event{body: %TestEvent{}} -> true end)
          })
        )

        send(
          pid,
          perform(id, %Receive{
            event_filter: Filter.new(fn %Event{body: %TestEvent{}} -> true end)
          })
        )

        Automaton.finish()
      end
    end

    test "subscribes messages" do
      saga_id = SagaID.new()

      Dispatcher.dispatch(
        Event.new(nil, %StartSaga{
          id: saga_id,
          saga: %TestAutomaton{pid: self()}
        })
      )

      assert_receive :ok
      event = Event.new(nil, %TestEvent{value: :a})
      Dispatcher.dispatch(event)
      assert_receive ^event
    end
  end
end
