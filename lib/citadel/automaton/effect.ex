defmodule Citadel.Automaton.Effect do
  @moduledoc """
  The effect behaviour.
  """

  alias Citadel.Event
  alias Citadel.SagaID

  @type t :: struct
  @type handler :: SagaID.t()
  @type resolve :: {:resolve, term}
  @type consume :: {:consume, term}

  @callback init(handler, t) :: resolve | term
  @callback handle_event(handler, Event.t(), t, state :: term) :: resolve | consume | term

  @spec init(handler, t) :: resolve | term
  def init(handler, effect) do
    module = effect.__struct__
    module.init(handler, effect)
  end

  @spec handle_event(handler, Event.t(), t, state :: term) :: resolve | consume | term
  def handle_event(handler, event, effect, state) do
    module = effect.__struct__
    module.handle_event(handler, event, effect, state)
  end
end
