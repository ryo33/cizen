defmodule Cizen.RequestTest do
  use ExUnit.Case, async: true

  alias Cizen.Event
  alias Cizen.EventFilter
  alias Cizen.EventID

  defmodule Request do
    defstruct [:value]
    use Cizen.Request

    defresponse ResponseA, :request_id do
      defstruct [:request_id, :value]
    end

    defresponse ResponseB, :request_id do
      defstruct [:request_id, :value]
    end
  end

  describe "use Request" do
    test "works" do
      # Defines response_event_filters/1
      event = Event.new(nil, %Request{value: :somevalue})
      [event_filter_b, event_filter_a] = Request.response_event_filters(event)
      # Matches
      assert EventFilter.test(
               event_filter_a,
               Event.new(nil, %Request.ResponseA{
                 request_id: event.id,
                 value: :somevalue
               })
             )

      true
      # Does not matches
      refute EventFilter.test(
               event_filter_a,
               Event.new(nil, %Request.ResponseA{
                 request_id: EventID.new(),
                 value: :somevalue
               })
             )

      # Matches
      assert EventFilter.test(
               event_filter_b,
               Event.new(nil, %Request.ResponseB{
                 request_id: event.id,
                 value: :somevalue
               })
             )

      true
      # Does not matches
      refute EventFilter.test(
               event_filter_b,
               Event.new(nil, %Request.ResponseB{
                 request_id: EventID.new(),
                 value: :somevalue
               })
             )
    end
  end
end
