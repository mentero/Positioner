defmodule Positioner.Repo.Migrations.CreateIndexOnPosition do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create index("dummies", [:position], concurrently: true)
  end
end
