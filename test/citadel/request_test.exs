defmodule Citadel.RequestTest do
  use ExUnit.Case, async: true

  alias Citadel.Event
  alias Citadel.EventFilter
  alias Citadel.EventID

  defmodule Request do
    defstruct [:value]
    import Citadel.Request

    defresponse Response, :request_id do
      defstruct [:request_id, :value]
    end
  end

  describe "Request.defresponse/3" do
    test "works" do
      # Defines response_event_filters/1
      event = Event.new(%Request{value: :somevalue})
      [event_filter] = Request.response_event_filters(event)
      # Matches
      assert EventFilter.test(
               event_filter,
               Event.new(%Request.Response{
                 request_id: event.id,
                 value: :somevalue
               })
             )

      true
      # Does not matches
      refute EventFilter.test(
               event_filter,
               Event.new(%Request.Response{
                 request_id: EventID.new(),
                 value: :something
               })
             )
    end
  end
end
