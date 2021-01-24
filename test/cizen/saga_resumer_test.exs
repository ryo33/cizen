defmodule Cizen.SagaResumerTest do
  use Cizen.SagaCase
  doctest Cizen.SagaResumer

  alias Cizen.{Dispatcher, Event, Filter}
  alias Cizen.Saga
  alias Cizen.SagaID
  alias Cizen.TestSaga

  alias Cizen.ResumeSaga

  require Filter

  test "ResumeSaga event" do
    pid = self()
    saga_id = SagaID.new()
    state = :some_state

    Dispatcher.listen(Filter.new(fn %Event{body: %Saga.Resumed{id: ^saga_id}} -> true end))

    Dispatcher.dispatch(
      Event.new(nil, %ResumeSaga{
        id: saga_id,
        saga: %TestSaga{
          resume: fn id, saga, state ->
            send(pid, {id, saga, state})
          end
        },
        state: state
      })
    )

    assert_receive {^saga_id, %TestSaga{}, ^state}
    assert_receive %Event{body: %Saga.Resumed{}}
  end
end
