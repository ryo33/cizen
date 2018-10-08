defmodule Citadel.EffectfulTest do
  use Citadel.SagaCase

  alias Citadel.Dispatcher
  alias Citadel.Event

  alias Citadel.Effects.{Dispatch}

  defmodule(TestEvent, do: defstruct([:value]))

  defmodule TestModule do
    use Citadel.Effectful

    def dispatch(body) do
      handle(fn id ->
        perform(id, %Dispatch{body: body})
      end)
    end

    def block do
      handle(fn _id ->
        # Block
        receive do
          _ -> :ok
        end
      end)
    end

    def return(value) do
      handle(fn _id ->
        value
      end)
    end
  end

  describe "handle/1" do
    test "handles effect" do
      Dispatcher.listen_event_type(TestEvent)

      spawn_link(fn ->
        TestModule.dispatch(%TestEvent{value: :somevalue})
      end)

      assert_receive %Event{body: %TestEvent{value: :somevalue}}
    end

    test "blocks the current thread" do
      spawn_link(fn ->
        TestModule.block()
        flunk("called")
      end)

      :timer.sleep(10)
    end

    test "returns the last expression" do
      task =
        Task.async(fn ->
          TestModule.return(:somevalue)
        end)

      assert :somevalue == Task.await(task)
    end
  end
end
