defmodule Cizen.Effects.Subscribe do
  @moduledoc """
  An effect to subscribe messages.

  Returns :ok.

  ## Example
      perform id, %Subscribe{
        event_filter: Filter.new(fn %Event{body: %SomeEvent{}} -> true end),
        lifetime_saga_id: some_saga_id
      }
  """

  @enforce_keys [:event_filter]
  defstruct [:event_filter, :lifetime_saga_id]

  alias Cizen.Effect
  alias Cizen.Effects.{Map, Request}

  alias Cizen.SubscribeMessage

  use Effect

  @impl true
  def expand(id, %__MODULE__{} = saga) do
    %__MODULE__{
      event_filter: event_filter,
      lifetime_saga_id: lifetime_saga_id
    } = saga

    %Map{
      effect: %Request{
        body: %SubscribeMessage{
          subscriber_saga_id: id,
          event_filter: event_filter,
          lifetime_saga_id: lifetime_saga_id
        }
      },
      transform: fn _response -> :ok end
    }
  end
end
