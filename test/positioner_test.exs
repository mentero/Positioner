defmodule PositionerTest do
  use Positioner.TestCase

  import Ecto.Changeset
  import Ecto.Query

  alias Positioner.Repo

  def insert_dummy!(attrs \\ []) do
    %Dummy{tenant: %Tenant{}}
    |> struct(attrs)
    |> Repo.insert!()
  end

  def insert_tenant!(attrs \\ []) do
    %Tenant{} |> struct(attrs) |> Repo.insert!()
  end

  describe "insert!" do
    test "there are no records" do
      tenant = insert_tenant!()

      assert %{id: d1, position: 1} =
               %Dummy{}
               |> create_changeset(tenant, %{})
               |> Repo.insert!()

      assert [%{id: ^d1, position: 1}] =
               Dummy |> select([:id, :position]) |> order_by(asc: :position) |> Repo.all()
    end

    test "there are multiple records" do
      tenant = insert_tenant!()

      %{id: d1} = insert_dummy!(position: 1, tenant: tenant)
      %{id: d2} = insert_dummy!(position: 2, tenant: tenant)
      %{id: d3} = insert_dummy!(position: 3, tenant: tenant)

      assert %{id: d4, position: 4} =
               %Dummy{}
               |> create_changeset(tenant, %{})
               |> Repo.insert!()

      assert [
               %{id: ^d1, position: 1},
               %{id: ^d2, position: 2},
               %{id: ^d3, position: 3},
               %{id: ^d4, position: 4}
             ] = Dummy |> select([:id, :position]) |> order_by(asc: :position) |> Repo.all()
    end

    test "inserting in between other records" do
      tenant = insert_tenant!()

      %{id: d1} = insert_dummy!(position: 1, tenant: tenant)
      %{id: d2} = insert_dummy!(position: 2, tenant: tenant)
      %{id: d3} = insert_dummy!(position: 3, tenant: tenant)

      assert %{id: d4, position: 2} =
               %Dummy{}
               |> create_changeset(tenant, %{"position" => 2})
               |> Repo.insert!()

      assert [
               %{id: ^d1, position: 1},
               %{id: ^d4, position: 2},
               %{id: ^d2, position: 3},
               %{id: ^d3, position: 4}
             ] = Dummy |> select([:id, :position]) |> order_by(asc: :position) |> Repo.all()
    end

    defp create_changeset(model, tenant, params) do
      model
      |> cast(params, [:position])
      |> put_change(:tenant_id, tenant.id)
      |> set_order()
    end

    defp set_order(changeset) do
      prepare_changes(changeset, fn changeset ->
        tenant_id = fetch_field!(changeset, :tenant_id)
        position = fetch_field!(changeset, :position)

        if position do
          Positioner.insert_at(Dummy, [tenant_id: tenant_id], :position, position)
          changeset
        else
          new_position = Positioner.position_for_new(Dummy, tenant_id: tenant_id)
          changeset |> change(position: new_position)
        end
      end)
    end
  end
end
