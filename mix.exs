defmodule Supra.MixProject do
  use Mix.Project

  @scm_url "https://github.com/synchronal/supra"
  @version "0.1.0"

  def project do
    [
      app: :supra,
      deps: deps(),
      description: "Common functions and macros for Ecto",
      dialyzer: dialyzer(),
      docs: docs(),
      elixir: "~> 1.13",
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
      preferred_envs: [credo: :test, dialyzer: :test]
    ]

  # # #

  defp deps,
    do: [
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.1", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.28", only: [:docs, :dev], runtime: false},
      {:mix_audit, "~> 2.0", only: :dev, runtime: false},
      {:moar, "~> 1.10", only: :test}
    ]

  defp dialyzer,
    do: [
      plt_add_apps: [:ex_unit, :mix],
      plt_add_deps: :app_tree,
      plt_core_path: "_build/#{Mix.env()}",
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
    ]

  defp docs,
    do: []

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
