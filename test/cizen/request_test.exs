defmodule Cizen.RequestTest do
  use ExUnit.Case, async: true

  alias Cizen.Event
  alias Cizen.EventID
  alias Cizen.Filter

  defmodule Request do
    defstruct [:value]
    use Cizen.Request

    defresponse ResponseA, :request_id do
      defstruct [:request_id, :value]
    end

    defresponse ResponseB, :request_id do
      defstruct [:request_id, :value]
    end

    defmodule Dummy do
      defstruct [:request_id, :value]
    end
  end

  describe "use Request" do
    test "works" do
      # Defines response_event_filter/1
      event = Event.new(nil, %Request{value: :somevalue})
      filter = Request.response_event_filter(event)
      # Matches
      assert Filter.match?(
               filter,
               Event.new(nil, %Request.ResponseA{
                 request_id: event.id,
                 value: :somevalue
               })
             )

      # Does not matches
      refute Filter.match?(
               filter,
               Event.new(nil, %Request.ResponseA{
                 request_id: EventID.new(),
                 value: :somevalue
               })
             )

      # Matches
      assert Filter.match?(
               filter,
               Event.new(nil, %Request.ResponseB{
                 request_id: event.id,
                 value: :somevalue
               })
             )

      # Does not matches
      refute Filter.match?(
               filter,
               Event.new(nil, %Request.ResponseB{
                 request_id: EventID.new(),
                 value: :somevalue
               })
             )

      # Does not matches
      refute Filter.match?(
               filter,
               Event.new(nil, %Request.Dummy{
                 request_id: event.id,
                 value: :somevalue
               })
             )
    end
  end
end
