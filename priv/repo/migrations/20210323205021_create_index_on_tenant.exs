defmodule Positioner.Repo.Migrations.CreateIndexOnTenant do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create index("dummies", [:tenant_id], concurrently: true)

  end
end
