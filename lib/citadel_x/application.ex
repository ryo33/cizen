defmodule CitadelX.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec
    # List all child processes to be supervised
    children = [
      # Starts a worker by calling: CitadelX.Worker.start_link(arg)
      worker(CitadelX.Dispatcher, [], restart: :permanent)
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CitadelX.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
