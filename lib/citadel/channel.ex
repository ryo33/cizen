defmodule Citadel.Channel do
  @moduledoc """
  A channel interferes messaging.
  """

  alias Citadel.SagaID

  @type t :: %__MODULE__{
          saga_id: SagaID.t(),
          saga_module: module,
          previous_channel_module: module | nil
        }

  @enforce_keys [:saga_id, :saga_module]
  defstruct [
    :saga_id,
    :saga_module,
    :previous_channel_module
  ]

  defmodule FeedMessage do
    @moduledoc """
    An event to feed an event to a channel.
    """

    @keys [:connection_id, :channel, :message]
    @enforce_keys @keys
    defstruct @keys
  end

  defmodule EmitMessage do
    @moduledoc """
    An event to emit an event from a channel.
    """

    @keys [:connection_id, :channel, :message]
    @enforce_keys @keys
    defstruct @keys

    defmodule ConnectionIDFilter do
      @moduledoc """
      An event body filter to filter EmitMesssage by connection id
      """
      alias Citadel.EventBodyFilter
      @behaviour EventBodyFilter
      @impl true
      def test(event_body, connection_id) do
        event_body.connection_id == connection_id
      end
    end
  end

  defmodule RejectMessage do
    @moduledoc """
    An event to reject an message.
    """

    @keys [:connection_id, :channel, :message]
    @enforce_keys @keys
    defstruct @keys

    defmodule ConnectionIDFilter do
      @moduledoc """
      An event body filter to filter RejectMesssage by connection id
      """
      alias Citadel.EventBodyFilter
      @behaviour EventBodyFilter
      @impl true
      def test(event_body, connection_id) do
        event_body.connection_id == connection_id
      end
    end
  end

  @spec adjoin?(__MODULE__.t(), __MODULE__.t()) :: boolean
  def adjoin?(%__MODULE__{saga_module: module}, %__MODULE__{previous_channel_module: module}),
    do: true

  def adjoin?(_, _), do: false
end
