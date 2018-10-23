defmodule Cizen.Channel do
  @moduledoc """
  A channel interferes messaging.
  """

  defmodule FeedMessage do
    @moduledoc """
    An event to feed an event to a channel.
    """

    @keys [:channel_saga_id, :event, :subscribers]
    @enforce_keys @keys
    defstruct @keys
  end

  defmodule EmitMessage do
    @moduledoc """
    An event to emit an event from a channel.
    """

    @keys [:event, :subscribers]
    @enforce_keys @keys
    defstruct @keys
  end
end
