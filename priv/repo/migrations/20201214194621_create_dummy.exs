defmodule Positioner.Repo.Migrations.CreateDummy do
  use Ecto.Migration

  def up do
    Ecto.Migration.create_if_not_exists table("dummies") do
      add(:title, :string)
      add(:position, :integer)
      add(:idx, :integer)
      add(:tenant_id, references(:tenants, on_delete: :delete_all))

      timestamps()
    end
  end

  def down do
    drop(table("dummies"))
  end
end
