defmodule Citadel.TestSaga do
  @moduledoc false
  @behaviour Citadel.Saga

  @impl true
  def launch(id, state) do
    launch = Map.get(state, :launch, fn _, state -> state end)
    internal_state = Map.get(state, :state, nil)
    internal_state = launch.(id, internal_state)
    Map.put(state, :state, internal_state)
  end

  @impl true
  def handle_event(id, event, %{handle_event: handle_event} = state) do
    internal_state = handle_event.(id, event, state.state)
    Map.put(state, :state, internal_state)
  end
end
