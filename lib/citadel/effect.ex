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
end
