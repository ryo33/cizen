defmodule Cizen.Effect do
  @moduledoc """
  The effect behaviour.
  """

  alias Cizen.Event
  alias Cizen.SagaID

  @type t :: struct
  @type handler :: SagaID.t()
  @type alias_of :: {:alias_of, t}
  @type resolve :: {:resolve, term}
  @type consume :: {:consume, term}

  @callback expand(handler, t) :: t
  @callback init(handler, t) :: resolve | alias_of | term
  @callback handle_event(handler, Event.t(), t, state :: term) :: resolve | consume | term

  @spec init(handler, t) :: resolve | {t, term}
  def init(handler, effect) do
    module = effect.__struct__

    case module.init(handler, effect) do
      {:resolve, result} -> {:resolve, result}
      {:alias_of, effect} -> init(handler, effect)
      other -> {effect, other}
    end
  end

  @spec handle_event(handler, Event.t(), t, state :: term) :: resolve | consume | term
  def handle_event(handler, event, effect, state) do
    module = effect.__struct__
    module.handle_event(handler, event, effect, state)
  end

  defmacro __using__(_opts) do
    quote do
      alias Cizen.Effect
      @behaviour Effect
      @impl true
      def expand(_handler, effect), do: effect
      @impl true
      def init(handler, effect) do
        Effect.do_init(handler, effect, &expand/2)
      end

      @impl true
      def handle_event(_, _, _, state), do: state
      defoverridable expand: 2, init: 2, handle_event: 4
    end
  end

  @doc false
  def do_init(handler, effect, new) do
    new_effect = new.(handler, effect)

    if new_effect == effect do
      init(handler, effect)
    else
      {:alias_of, new_effect}
    end
  end
end
