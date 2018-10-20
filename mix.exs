defmodule Cizen.MixProject do
  use Mix.Project

  def project do
    [
      app: :cizen,
      version: "0.3.0",
      package: package(),
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      source_url: "https://gitlab.com/cizen/cizen",
      description: """
      Build highly concurrent, monitorable, and extensible applications with a collection of automata.
      """
    ]
  end

  def application do
    [
      start_phases: [start_children: [], start_daemons: []],
      extra_applications: [:logger],
      mod: {Cizen.Application, []}
    ]
  end

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

  defp package do
    [
      links: %{gitlab: "https://gitlab.com/cizen/cizen"},
      licenses: ["MIT"]
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

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
