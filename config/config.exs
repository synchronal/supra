# Configuration for the test environments

import Config

if Mix.env() == :test do
  config :logger, level: :warning, metadata: :all

  config :supra, ecto_repos: [Test.Repo]

  config :supra, Test.Repo,
    database: "supra_test",
    hostname: "localhost",
    password: "postgres",
    pool_size: 16,
    pool: Ecto.Adapters.SQL.Sandbox,
    port: String.to_integer(System.get_env("PGPORT", "5432")),
    queue_interval: 5000,
    queue_target: 300,
    username: "postgres"
end
