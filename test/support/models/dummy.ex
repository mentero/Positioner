defmodule Dummy do
  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "dummies" do
    field(:title, :string)
    field(:position, :integer)
    field(:idx, :integer)
    belongs_to(:tenant, Tenant)

    timestamps()
  end

  @spec create_changeset(t(), Tenant.t(), map()) :: Ecto.Changeset.t()
  def create_changeset(model, tenant, params) do
    model
    |> cast(params, [:position])
    |> put_change(:tenant_id, tenant.id)
    |> Positioner.Changeset.set_order(:position, [:tenant_id])
  end

  @spec update_changeset(t(), Tenant.t(), map()) :: Ecto.Changeset.t()
  def update_changeset(model, _tenant, params) do
    model
    |> cast(params, [:title, :position, :tenant_id])
    |> Positioner.Changeset.set_order(:position, [:tenant_id])
  end

  @spec delete_changeset(t()) :: Ecto.Changeset.t()
  def delete_changeset(model) do
    model |> change() |> Positioner.Changeset.set_order(:position, [:tenant_id])
  end
end
