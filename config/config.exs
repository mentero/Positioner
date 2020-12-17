use Mix.Config

config :positioner, Positioner.Repo,
  username: System.get_env("TEST_DB_USERNAME") || "development",
  password: System.get_env("TEST_DB_PASSWORD") || "development",
  database: System.get_env("TEST_DB_NAME") || "positioner_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox,
  ownership_timeout: 300_000,
  timeout: 300_000

config :positioner, Positioner.MigrationRepo,
  username: System.get_env("TEST_DB_USERNAME") || "development",
  password: System.get_env("TEST_DB_PASSWORD") || "development",
  database: System.get_env("TEST_DB_NAME") || "positioner_test",
  hostname: "localhost",
  migration_source: "test_schema_migrations",
  migration_primary_key: [type: :serial],
  migration_timestamps: [type: :utc_datetime_usec],
  pool: Ecto.Adapters.SQL.Sandbox,
  ownership_timeout: 300_000,
  timeout: 300_000

config :positioner, repo: Positioner.Repo
config :positioner, ecto_repos: [Positioner.Repo]
