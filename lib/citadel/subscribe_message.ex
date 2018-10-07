defmodule Citadel.SubscribeMessage do
  @moduledoc """
  An event to subscribe message
  """

  alias Citadel.Event
  alias Citadel.EventBodyFilter
  alias Citadel.EventBodyFilterSet
  alias Citadel.EventFilter

  @enforce_keys [:subscriber_saga_id, :event_filter]
  defstruct [
    :subscriber_saga_id,
    :subscriber_saga_module,
    :event_filter
  ]

  defmodule Subscribed do
    @moduledoc """
    An event to notify that SubscribeMessage event is successfully handled.
    """

    @keys [:event_id]
    @enforce_keys @keys
    defstruct @keys

    defmodule EventIDFilter do
      @moduledoc """
      An event body filter to filter SubscribeMessage.Subscribed by event id
      """
      @enforce_keys [:value]
      defstruct [:value]
      @behaviour EventBodyFilter
      @impl true
      def test(%__MODULE__{value: event_id}, event_body) do
        event_body.event_id == event_id
      end
    end
  end

  @behaviour Citadel.Request
  @impl true
  def response_event_filters(%Event{id: id}) do
    [
      %EventFilter{
        event_type: Subscribed,
        event_body_filter_set:
          EventBodyFilterSet.new([
            %Subscribed.EventIDFilter{value: id}
          ])
      }
    ]
  end
end
