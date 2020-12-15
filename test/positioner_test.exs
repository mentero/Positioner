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
      |> Positioner.Changeset.set_order([:tenant_id])
    end
  end

  describe "update!" do
    test "position didn't change" do
      tenant = insert_tenant!()

      %{id: d1} = insert_dummy!(title: "1", position: 1, tenant: tenant)
      %{id: d2} = insert_dummy!(title: "2", position: 2, tenant: tenant)
      %{id: d3} = subject = insert_dummy!(title: "3", position: 3, tenant: tenant)
      %{id: d4} = insert_dummy!(title: "4", position: 4, tenant: tenant)

      assert %{id: ^d3, title: "subject", position: 3} =
               subject
               |> update_changeset(tenant, %{"title" => "subject"})
               |> Repo.update!()

      assert [
               %{id: ^d1, title: "1", position: 1},
               %{id: ^d2, title: "2", position: 2},
               %{id: ^d3, title: "subject", position: 3},
               %{id: ^d4, title: "4", position: 4}
             ] =
               Dummy |> select([:id, :title, :position]) |> order_by(asc: :position) |> Repo.all()
    end

    test "position have changed" do
      tenant = insert_tenant!()

      %{id: d1} = insert_dummy!(title: "1", position: 1, tenant: tenant)
      %{id: d2} = insert_dummy!(title: "2", position: 2, tenant: tenant)
      %{id: d3} = subject = insert_dummy!(title: "3", position: 3, tenant: tenant)
      %{id: d4} = insert_dummy!(title: "4", position: 4, tenant: tenant)

      assert %{id: ^d3, title: "subject", position: 2} =
               subject
               |> update_changeset(tenant, %{"title" => "subject", "position" => 2})
               |> Repo.update!()

      assert [
               %{id: ^d1, title: "1", position: 1},
               %{id: ^d3, title: "subject", position: 2},
               %{id: ^d2, title: "2", position: 3},
               %{id: ^d4, title: "4", position: 4}
             ] =
               Dummy |> select([:id, :title, :position]) |> order_by(asc: :position) |> Repo.all()
    end

    @tag :skip
    test "scope changed" do
      # TO BE IMPLEMENTED
    end

    defp update_changeset(model, tenant, params) do
      model
      |> cast(params, [:title, :position])
      |> Positioner.Changeset.set_order([:tenant_id])
    end
  end

  describe "delete!" do
    test "delete from the collection" do
      tenant = insert_tenant!()

      %{id: d1} = insert_dummy!(title: "1", position: 1, tenant: tenant)
      %{id: d2} = insert_dummy!(title: "2", position: 2, tenant: tenant)
      %{id: d3} = subject = insert_dummy!(title: "3", position: 3, tenant: tenant)
      %{id: d4} = insert_dummy!(title: "4", position: 4, tenant: tenant)

      assert %{id: ^d3, title: "3", position: 3} =
               subject
               |> delete_changeset()
               |> Repo.delete!()

      assert [
               %{id: ^d1, title: "1", position: 1},
               %{id: ^d2, title: "2", position: 2},
               %{id: ^d4, title: "4", position: 3}
             ] =
               Dummy |> select([:id, :title, :position]) |> order_by(asc: :position) |> Repo.all()
    end

    defp delete_changeset(model) do
      model |> change() |> Positioner.Changeset.set_order([:tenant_id])
    end
  end
end
