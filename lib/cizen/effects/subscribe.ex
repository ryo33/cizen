defmodule Cizen.Effects.Subscribe do
  @moduledoc """
  An effect to subscribe messages.

  Returns :ok.

  ## Example
      perform id, %Subscribe{
        event_filter: EventFilter.new(event_type: some_event_type)
      }
  """

  defstruct [:event_filter]

  alias Cizen.Effect
  alias Cizen.Effects.{Map, Request}

  alias Cizen.SubscribeMessage

  @behaviour Effect

  @impl true
  def init(id, %__MODULE__{event_filter: event_filter}) do
    effect = %Map{
      effect: %Request{
        body: %SubscribeMessage{subscriber_saga_id: id, event_filter: event_filter}
      },
      transform: fn _response -> :ok end
    }

    {:alias_of, effect}
  end

  @impl true
  def handle_event(_, _, _, _), do: :ok
end