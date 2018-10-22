defmodule Cizen.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      # Starts a worker by calling: Cizen.Worker.start_link(arg)
      %{
        id: Cizen.Dispatcher,
        start: {Cizen.Dispatcher, :start_link, []}
      },
      %{
        id: Cizen.CizenSagaRegistry,
        start: {Cizen.CizenSagaRegistry, :start_link, []}
      }
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Cizen.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def start_phase(:start_children, _start_type, _args) do
    Supervisor.start_child(Cizen.Supervisor, %{
      id: Cizen.SagaLauncher,
      start: {Cizen.SagaLauncher, :start_link, []}
    })

    Supervisor.start_child(Cizen.Supervisor, %{
      id: Cizen.EventFilterDispatcher.EventPusher,
      start: {Cizen.EventFilterDispatcher.EventPusher, :start_link, []}
    })

    Supervisor.start_child(Cizen.Supervisor, %{
      id: Cizen.EventFilterDispatcher,
      start: {Cizen.EventFilterDispatcher, :start_link, []}
    })

    Supervisor.start_child(Cizen.Supervisor, %{
      id: Cizen.Transmitter,
      start: {Cizen.Transmitter, :start_link, []}
    })

    Supervisor.start_child(Cizen.Supervisor, %{
      id: Cizen.SagaMonitor,
      start: {Cizen.SagaMonitor, :start_link, []}
    })

    Supervisor.start_child(Cizen.Supervisor, %{
      id: Cizen.Automaton.EffectSender,
      start: {Cizen.Automaton.EffectSender, :start_link, []}
    })

    :ok
  end

  def start_phase(:start_daemons, _start_type, _args) do
    alias Cizen.SagaLauncher
    SagaLauncher.launch_saga(%Cizen.Messenger{})
    SagaLauncher.launch_saga(%Cizen.SagaStarter{})
    SagaLauncher.launch_saga(%Cizen.SagaEnder{})
    SagaLauncher.launch_saga(%Cizen.RequestResponseMediator{})
    SagaLauncher.launch_saga(%Cizen.CrashLogger{})
    :ok
  end
end
