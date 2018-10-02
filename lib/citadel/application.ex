defmodule Citadel.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      # Starts a worker by calling: Citadel.Worker.start_link(arg)
      %{
        id: Citadel.Dispatcher,
        start: {Citadel.Dispatcher, :start_link, []}
      },
      %{
        id: Citadel.SagaRegistry,
        start: {Citadel.SagaRegistry, :start_link, []}
      }
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Citadel.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def start_phase(:start_children, _start_type, _args) do
    Supervisor.start_child(Citadel.Supervisor, %{
      id: Citadel.SagaLauncher,
      start: {Citadel.SagaLauncher, :start_link, []}
    })

    Supervisor.start_child(Citadel.Supervisor, %{
      id: Citadel.EventFilterDispatcher.EventPusher,
      start: {Citadel.EventFilterDispatcher.EventPusher, :start_link, []}
    })

    Supervisor.start_child(Citadel.Supervisor, %{
      id: Citadel.EventFilterDispatcher,
      start: {Citadel.EventFilterDispatcher, :start_link, []}
    })

    Supervisor.start_child(Citadel.Supervisor, %{
      id: Citadel.Transmitter,
      start: {Citadel.Transmitter, :start_link, []}
    })

    :ok
  end

  def start_phase(:start_daemons, _start_type, _args) do
    alias Citadel.SagaLauncher
    SagaLauncher.launch_saga(Citadel.Messenger, :ok)
    :ok
  end
end
