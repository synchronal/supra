defmodule Supra.MixProject do
  use Mix.Project

  @scm_url "https://github.com/synchronal/supra"
  @version "3.1.1"

  def project do
    [
      aliases: aliases(),
      app: :supra,
      deps: deps(),
      description: "Common functions and macros for Ecto",
      dialyzer: dialyzer(),
      docs: docs(),
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      homepage_url: @scm_url,
      name: "Supra",
      package: package(),
      start_permanent: Mix.env() == :prod,
      version: @version
    ]
  end

  def application,
    do: [
      extra_applications: [:logger]
    ]

  def cli,
    do: [
      preferred_envs: [
        credo: :test,
        dialyzer: :test,
        "ecto.gen.migration": :test,
        "ecto.setup": :test,
        "ecto.reset": :test
      ]
    ]

  # # #

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end

  defp deps,
    do: [
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.1", only: [:dev, :test], runtime: false},
      {:ecto, "~> 3.0"},
      {:ecto_sql, "~> 3.0", optional: true},
      {:ecto_temp, "~> 2.0", only: :test, runtime: false},
      {:ex_doc, "~> 0.28", only: [:docs, :dev], runtime: false},
      {:mix_audit, "~> 2.0", only: :dev, runtime: false},
      {:mix_test_watch, "~> 1.2", runtime: false, only: :dev},
      {:moar, "~> 2.0", only: :test},
      {:postgrex, ">= 0.0.0", only: :test}
    ]

  defp dialyzer,
    do: [
      plt_add_apps: [:ex_unit, :mix],
      plt_add_deps: :app_tree,
      plt_core_path: "_build/plts/#{Mix.env()}",
      plt_local_path: "_build/plts/#{Mix.env()}"
    ]

  defp docs,
    do: [main: "Supra"]

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package,
    do: [
      files: ~w[lib .formatter.exs mix.exs README* LICENSE* CHANGELOG*],
      licenses: ["MIT"],
      maintainers: ["synchronal.dev", "Erik Hanson", "Eric Saxby"],
      links: %{"GitHub" => @scm_url}
    ]
end
