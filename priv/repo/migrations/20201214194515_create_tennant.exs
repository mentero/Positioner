defmodule Positioner.Repo.Migrations.CreateTennant do
  use Ecto.Migration

  def up do
    Ecto.Migration.create_if_not_exists table("tenants") do
      timestamps()
    end
  end

  def down do
    drop(table("tenants"))
  end
end
