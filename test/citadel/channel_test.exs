defmodule Cizen.ChannelTest do
  use Cizen.SagaCase

  alias Cizen.Channel
  alias Cizen.Event
  alias Cizen.Message
  alias Cizen.SagaID

  describe "adjoin?/2" do
    test "checks saga module" do
      assert true ==
               Channel.adjoin?(
                 %Channel{saga_id: SagaID.new(), saga_module: PreviousChannel},
                 %Channel{
                   saga_id: SagaID.new(),
                   saga_module: NextChannel,
                   previous_channel_module: PreviousChannel
                 }
               )

      assert false ==
               Channel.adjoin?(
                 %Channel{saga_id: SagaID.new(), saga_module: PreviousChannel},
                 %Channel{
                   saga_id: SagaID.new(),
                   saga_module: NextChannel,
                   previous_channel_module: UnknownChannel
                 }
               )
    end
  end

  defmodule(TestEvent, do: defstruct([:value]))

  describe "match?/2" do
    test "return true if destination is matched" do
      destination_saga_id = SagaID.new()

      assert true ==
               Channel.match?(
                 %Channel{
                   saga_id: SagaID.new(),
                   saga_module: TestChannel,
                   destination_saga_id: destination_saga_id,
                   destination_saga_module: TestSaga
                 },
                 %Message{
                   event: Event.new(%TestEvent{}),
                   destination_saga_id: destination_saga_id,
                   destination_saga_module: TestSaga
                 }
               )
    end

    test "nil means \"ignore\"" do
      destination_saga_id = SagaID.new()

      assert true ==
               Channel.match?(
                 %Channel{
                   saga_id: SagaID.new(),
                   saga_module: TestChannel,
                   destination_saga_id: nil,
                   destination_saga_module: TestSaga
                 },
                 %Message{
                   event: Event.new(%TestEvent{}),
                   destination_saga_id: destination_saga_id,
                   destination_saga_module: TestSaga
                 }
               )

      assert true ==
               Channel.match?(
                 %Channel{
                   saga_id: SagaID.new(),
                   saga_module: TestChannel,
                   destination_saga_id: destination_saga_id,
                   destination_saga_module: nil
                 },
                 %Message{
                   event: Event.new(%TestEvent{}),
                   destination_saga_id: destination_saga_id,
                   destination_saga_module: TestSaga
                 }
               )
    end

    test "returns false on mismatch" do
      destination_saga_id = SagaID.new()

      assert false ==
               Channel.match?(
                 %Channel{
                   saga_id: SagaID.new(),
                   saga_module: TestChannel,
                   destination_saga_id: SagaID.new(),
                   destination_saga_module: UnknownSaga
                 },
                 %Message{
                   event: Event.new(%TestEvent{}),
                   destination_saga_id: destination_saga_id,
                   destination_saga_module: TestSaga
                 }
               )

      assert false ==
               Channel.match?(
                 %Channel{
                   saga_id: SagaID.new(),
                   saga_module: TestChannel,
                   destination_saga_id: nil,
                   destination_saga_module: UnknownSaga
                 },
                 %Message{
                   event: Event.new(%TestEvent{}),
                   destination_saga_id: destination_saga_id,
                   destination_saga_module: TestSaga
                 }
               )

      assert false ==
               Channel.match?(
                 %Channel{
                   saga_id: SagaID.new(),
                   saga_module: TestChannel,
                   destination_saga_id: SagaID.new(),
                   destination_saga_module: nil
                 },
                 %Message{
                   event: Event.new(%TestEvent{}),
                   destination_saga_id: destination_saga_id,
                   destination_saga_module: TestSaga
                 }
               )
    end
  end
end
