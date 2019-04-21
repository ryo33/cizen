defmodule Cizen.TestSaga do
  @moduledoc false
  use Cizen.Saga

  defstruct [:init, :resume, :handle_event, :state, :extra]

  @impl true
  def init(id, %__MODULE__{init: init, handle_event: handle_event, state: state} = struct) do
    init = init || fn _, state -> state end
    handle_event = handle_event || fn _, _, state -> state end
    state = init.(id, state)
    %__MODULE__{struct | init: init, handle_event: handle_event, state: state}
  end

  @impl true
  def resume(id, %__MODULE__{resume: resume, handle_event: handle_event} = struct, state) do
    resume = resume || fn _, _, _ -> state end
    handle_event = handle_event || fn _, _, state -> state end
    state = resume.(id, struct, state)
    %__MODULE__{struct | resume: resume, handle_event: handle_event, state: state}
  end

  @impl true
  def handle_event(id, event, %__MODULE__{handle_event: handle_event, state: state} = struct) do
    state = handle_event.(id, event, state)
    %__MODULE__{struct | state: state}
  end
end
