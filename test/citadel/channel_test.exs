defmodule Citadel.ChannelTest do
  use ExUnit.Case

  alias Citadel.Channel
  alias Citadel.Event
  alias Citadel.Message
  alias Citadel.SagaID

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
    test "return true if subscriber is matched" do
      subscriber_saga_id = SagaID.new()

      assert true ==
               Channel.match?(
                 %Channel{
                   saga_id: SagaID.new(),
                   saga_module: TestChannel,
                   subscriber_saga_id: subscriber_saga_id,
                   subscriber_saga_module: TestSaga
                 },
                 %Message{
                   event: Event.new(%TestEvent{}),
                   subscriber_saga_id: subscriber_saga_id,
                   subscriber_saga_module: TestSaga
                 }
               )
    end

    test "nil means \"ignore\"" do
      subscriber_saga_id = SagaID.new()

      assert true ==
               Channel.match?(
                 %Channel{
                   saga_id: SagaID.new(),
                   saga_module: TestChannel,
                   subscriber_saga_id: nil,
                   subscriber_saga_module: TestSaga
                 },
                 %Message{
                   event: Event.new(%TestEvent{}),
                   subscriber_saga_id: subscriber_saga_id,
                   subscriber_saga_module: TestSaga
                 }
               )

      assert true ==
               Channel.match?(
                 %Channel{
                   saga_id: SagaID.new(),
                   saga_module: TestChannel,
                   subscriber_saga_id: subscriber_saga_id,
                   subscriber_saga_module: nil
                 },
                 %Message{
                   event: Event.new(%TestEvent{}),
                   subscriber_saga_id: subscriber_saga_id,
                   subscriber_saga_module: TestSaga
                 }
               )
    end

    test "returns false on mismatch" do
      subscriber_saga_id = SagaID.new()

      assert false ==
               Channel.match?(
                 %Channel{
                   saga_id: SagaID.new(),
                   saga_module: TestChannel,
                   subscriber_saga_id: SagaID.new(),
                   subscriber_saga_module: UnknownSaga
                 },
                 %Message{
                   event: Event.new(%TestEvent{}),
                   subscriber_saga_id: subscriber_saga_id,
                   subscriber_saga_module: TestSaga
                 }
               )

      assert false ==
               Channel.match?(
                 %Channel{
                   saga_id: SagaID.new(),
                   saga_module: TestChannel,
                   subscriber_saga_id: nil,
                   subscriber_saga_module: UnknownSaga
                 },
                 %Message{
                   event: Event.new(%TestEvent{}),
                   subscriber_saga_id: subscriber_saga_id,
                   subscriber_saga_module: TestSaga
                 }
               )

      assert false ==
               Channel.match?(
                 %Channel{
                   saga_id: SagaID.new(),
                   saga_module: TestChannel,
                   subscriber_saga_id: SagaID.new(),
                   subscriber_saga_module: nil
                 },
                 %Message{
                   event: Event.new(%TestEvent{}),
                   subscriber_saga_id: subscriber_saga_id,
                   subscriber_saga_module: TestSaga
                 }
               )
    end
  end
end
