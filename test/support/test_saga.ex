defmodule Citadel.TestSaga do
  @moduledoc false
  @behaviour Citadel.Saga

  defstruct [:launch, :handle_event, :state]

  @impl true
  def init(id, %__MODULE__{launch: launch, handle_event: handle_event, state: state} = struct) do
    launch = launch || fn _, state -> state end
    handle_event = handle_event || fn _, _, state -> state end
    state = launch.(id, state)
    %__MODULE__{struct | launch: launch, handle_event: handle_event, state: state}
  end

  @impl true
  def handle_event(id, event, %__MODULE__{handle_event: handle_event, state: state} = struct) do
    state = handle_event.(id, event, state)
    %__MODULE__{struct | state: state}
  end
end
