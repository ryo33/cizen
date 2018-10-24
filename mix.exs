defmodule Cizen.MixProject do
  use Mix.Project

  def project do
    [
      app: :cizen,
      version: "0.7.1",
      package: package(),
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "Cizen",
      docs: docs(),
      source_url: "https://gitlab.com/cizen/cizen",
      description: """
      Build highly concurrent, monitorable, and extensible applications with a collection of automata.
      """,
      aliases: aliases(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      start_phases: [start_children: [], start_daemons: []],
      extra_applications: [:logger],
      mod: {Cizen.Application, []}
    ]
  end

  defp package do
    [
      links: %{gitlab: "https://gitlab.com/cizen/cizen"},
      licenses: ["MIT"]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:elixir_uuid, "~> 1.2"},
      {:poison, "~> 4.0", only: :test, runtime: false},
      {:credo, "~> 0.10.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.3", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.8", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp docs do
    [
      main: "readme",
      extra_section: "GUIDES",
      groups_for_modules: groups_for_modules(),
      extras: extras(),
      groups_for_extras: groups_for_extras()
    ]
  end

  defp extras do
    [
      {"README.md", [filename: "readme", title: "Read Me"]},
      "guides/getting_started.md",

      "guides/basic_concepts/saga.md",
      "guides/basic_concepts/event.md",
      "guides/basic_concepts/automaton.md",
      "guides/basic_concepts/effect.md",
      "guides/basic_concepts/requestive_event.md",

      "guides/advanced_concepts/channel.md",
    ]
  end

  defp groups_for_extras do
    [
      "Guides": ~r/guides\/[^\/]+\.md/,
      "Basic Concepts": ~r/guides\/basic_concepts\/.?/,
      "Advanced Concepts": ~r/guides\/advanced_concepts\/.?/,
    ]
  end

  defp groups_for_modules do
    [
      "Automaton": [
        Cizen.Automaton,
        Cizen.Effectful,
      ],

      "Automaton Internal": [
        Cizen.Automaton.EffectSender,
        Cizen.Automaton.PerformEffect,
        Cizen.Effect,
        Cizen.EffectHandler,
      ],

      "Channel": [
        Cizen.Channel,
        Cizen.Channel.EmitMessage,
        Cizen.Channel.FeedMessage,
        Cizen.RegisterChannel,
        Cizen.RegisterChannel.Registered,
      ],

      "Channel Internal": [
        Cizen.RegisterChannel.Registered.EventIdFilter,
      ],

      "Dispatchers": [
        Cizen.Dispatcher,
        Cizen.EventFilterDispatcher,
        Cizen.EventFilterDispatcher.Subscribe,
        Cizen.EventFilterDispatcher.Subscribe.Subscribed,
        Cizen.EventFilterDispatcher.Subscription,
      ],

      "Dispatcher Internal": [
        Cizen.EventFilterDispatcher.EventPusher,
        Cizen.EventFilterDispatcher.PushEvent,
      ],

      "Effects": [
        Cizen.Effects,
        Cizen.Effects.All,
        Cizen.Effects.Dispatch,
        Cizen.Effects.End,
        Cizen.Effects.Chain,
        Cizen.Effects.Map,
        Cizen.Effects.Monitor,
        Cizen.Effects.Race,
        Cizen.Effects.Receive,
        Cizen.Effects.Request,
        Cizen.Effects.Start,
        Cizen.Effects.Subscribe,
      ],

      "Effects Internal": [
        Cizen.Effects.HybridMap,
      ],

      "Effectful": [
        Cizen.Effectful,
      ],

      "Event": [
        Cizen.Event,
        Cizen.EventBodyFilter,
        Cizen.EventBodyFilterSet,
        Cizen.EventFilter,
        Cizen.EventID,
        Cizen.SagaFilter,
        Cizen.SagaFilterSet,
      ],

      "Messaging": [
        Cizen.Message,
        Cizen.ReceiveMessage,
        Cizen.SubscribeMessage,
        Cizen.SubscribeMessage.Subscribed,
        Cizen.SubscribeMessage.Subscribed.EventIdFilter,
      ],

      "Messaging Internal": [
        Cizen.Messenger,
        Cizen.Messenger.Transmitter,
        Cizen.SendMessage,
      ],

      "Requesting": [
        Cizen.Request,
        Cizen.Request.Response,
      ],

      "Requesting Internal": [
        Cizen.Request.Response.RequestEventIDFilter,
        Cizen.RequestResponseMediator,
        Cizen.RequestResponseMediator.Worker,
      ],

      "Saga": [
        Cizen.CizenSagaRegistry,
        Cizen.CrashLogger,
        Cizen.EndSaga,
        Cizen.MonitorSaga,
        Cizen.MonitorSaga.Down,
        Cizen.Saga,
        Cizen.Saga.Crashed,
        Cizen.Saga.Finish,
        Cizen.Saga.Finished,
        Cizen.Saga.Launched,
        Cizen.Saga.Launched.SagaIDFilter,
        Cizen.Saga.Unlaunched,
        Cizen.SagaID,
        Cizen.SagaMonitor,
        Cizen.SagaRegistry,
        Cizen.StartSaga,
        Cizen.StartSaga.SagaFilter,
        Cizen.StartSaga.SagaModuleFilter,
      ],

      "Saga Internal": [
        Cizen.MonitorSaga.Down.TargetSagaIDFilter,
        Cizen.SagaEnder,
        Cizen.SagaLauncher,
        Cizen.SagaLauncher.LaunchSaga,
        Cizen.SagaLauncher.UnlaunchSaga,
        Cizen.SagaStarter,
      ]
    ]
  end

  defp aliases do
    [
      credo: ["credo --strict"],
      check: [
        "compile --warnings-as-errors",
        "format --check-formatted --check-equivalent",
        "credo --strict",
        "dialyzer --no-compile --halt-exit-status"
      ]
    ]
  end
end
