defmodule Citadel.ChannelTest do
  use ExUnit.Case

  alias Citadel.Channel
  alias Citadel.SagaID

  describe "adjoin?/2" do
    test "checks saga_module" do
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
end
