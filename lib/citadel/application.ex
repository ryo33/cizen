defmodule Citadel.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      # Starts a worker by calling: Citadel.Worker.start_link(arg)
      %{
        id: Citadel.Dispatcher,
        start: {Citadel.Dispatcher, :start_link, []}
      },
      %{
        id: Citadel.AutomatonLauncher,
        start: {Citadel.AutomatonLauncher, :start_link, []}
      },
      Citadel.AutomatonSupervisor
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Citadel.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
