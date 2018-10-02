defmodule Citadel.SagaMonitor do
  @moduledoc """
  Monitors a saga and finishes when the saga finishes, crashes, or doesn't exists.
  """

  @keys [:target_saga_id]
  @enforce_keys @keys
  defstruct @keys

  alias Citadel.Dispatcher
  alias Citadel.Event
  alias Citadel.Saga
  alias Citadel.SagaRegistry

  @behaviour Saga

  @impl true
  def init(id, target_id) do
    case SagaRegistry.resolve_id(target_id) do
      {:ok, pid} ->
        Task.start_link(fn ->
          ref = Process.monitor(pid)

          receive do
            {:DOWN, ^ref, :process, _, _} ->
              finish(id)
          end
        end)

      :error ->
        finish(id)
    end

    :ok
  end

  @impl true
  def handle_event(_id, _event, state), do: state

  defp finish(id) do
    Dispatcher.dispatch(Event.new(%Saga.Finish{id: id}))
  end
end
