defmodule Positioner.ChangesetTest do
  use Positioner.TestCase

  import Positioner.TestHelpers

  alias Positioner.Repo

  describe "Inserting new record" do
    test "at first position if there are no other records" do
      tenant = insert_tenant!()

      assert %{id: dummy_1, position: 1} =
               %Dummy{}
               |> Dummy.create_changeset(tenant, %{})
               |> Repo.insert!()

      assert [%{id: ^dummy_1, position: 1}] = all_dummies!()
    end

    test "at the end if there are multiple records" do
      tenant = insert_tenant!()

      %{id: dummy_1} = insert_dummy!(position: 1, tenant: tenant)
      %{id: dummy_2} = insert_dummy!(position: 2, tenant: tenant)
      %{id: dummy_3} = insert_dummy!(position: 3, tenant: tenant)

      assert %{id: dummy_4, position: 4} =
               %Dummy{}
               |> Dummy.create_changeset(tenant, %{})
               |> Repo.insert!()

      assert [
               %{id: ^dummy_1, position: 1},
               %{id: ^dummy_2, position: 2},
               %{id: ^dummy_3, position: 3},
               %{id: ^dummy_4, position: 4}
             ] = all_dummies!()
    end

    test "in between other records" do
      tenant = insert_tenant!()

      %{id: dummy_1} = insert_dummy!(position: 1, tenant: tenant)
      %{id: dummy_2} = insert_dummy!(position: 2, tenant: tenant)
      %{id: dummy_3} = insert_dummy!(position: 3, tenant: tenant)

      assert %{id: dummy_4, position: 2} =
               %Dummy{}
               |> Dummy.create_changeset(tenant, %{"position" => 2})
               |> Repo.insert!()

      assert [
               %{id: ^dummy_1, position: 1},
               %{id: ^dummy_4, position: 2},
               %{id: ^dummy_2, position: 3},
               %{id: ^dummy_3, position: 4}
             ] = all_dummies!()
    end

    test "at the position far above the scope" do
      tenant = insert_tenant!()

      %{id: dummy_1} = insert_dummy!(position: 1, tenant: tenant)
      %{id: dummy_2} = insert_dummy!(position: 2, tenant: tenant)
      %{id: dummy_3} = insert_dummy!(position: 3, tenant: tenant)

      assert %{id: dummy_4, position: 4} =
               %Dummy{}
               |> Dummy.create_changeset(tenant, %{"position" => 100})
               |> Repo.insert!()

      assert [
               %{id: ^dummy_1, position: 1},
               %{id: ^dummy_2, position: 2},
               %{id: ^dummy_3, position: 3},
               %{id: ^dummy_4, position: 4}
             ] = all_dummies!()
    end

    test "respects the scope" do
      tenant = insert_tenant!()
      another_tenant = insert_tenant!()

      %{id: dummy_1} = insert_dummy!(position: 1, tenant: tenant)
      %{id: dummy_2} = insert_dummy!(position: 2, tenant: tenant)
      %{id: dummy_3} = insert_dummy!(position: 3, tenant: tenant)

      %{id: another_dummy_1} = insert_dummy!(position: 1, tenant: another_tenant)
      %{id: another_dummy_2} = insert_dummy!(position: 2, tenant: another_tenant)
      %{id: another_dummy_3} = insert_dummy!(position: 3, tenant: another_tenant)

      assert %{id: dummy_4, position: 2} =
               %Dummy{}
               |> Dummy.create_changeset(tenant, %{"position" => 2})
               |> Repo.insert!()

      assert [
               %{id: ^dummy_1, position: 1},
               %{id: ^dummy_4, position: 2},
               %{id: ^dummy_2, position: 3},
               %{id: ^dummy_3, position: 4},
               %{id: ^another_dummy_1, position: 1},
               %{id: ^another_dummy_2, position: 2},
               %{id: ^another_dummy_3, position: 3}
             ] = all_dummies!()
    end

    test "some records have nil position (don't know, but hey! programming!)" do
      tenant = insert_tenant!()

      %{id: dummy_1} = insert_dummy!(position: 1, tenant: tenant)
      %{id: dummy_2} = insert_dummy!(position: nil, tenant: tenant)
      %{id: dummy_3} = insert_dummy!(position: nil, tenant: tenant)

      assert %{id: dummy_4, position: 2} =
               %Dummy{}
               |> Dummy.create_changeset(tenant, %{"position" => 2})
               |> Repo.insert!()

      assert [
               %{id: ^dummy_1, position: 1},
               %{id: ^dummy_4, position: 2},
               %{id: ^dummy_2, position: 3},
               %{id: ^dummy_3, position: 4}
             ] = all_dummies!()
    end
  end

  describe "Updating record position" do
    test "have no effect if it didn't change" do
      tenant = insert_tenant!()

      %{id: dummy_1} = insert_dummy!(title: "1", position: 1, tenant: tenant)
      %{id: dummy_2} = insert_dummy!(title: "2", position: 2, tenant: tenant)
      %{id: dummy_3} = subject = insert_dummy!(title: "3", position: 3, tenant: tenant)
      %{id: dummy_4} = insert_dummy!(title: "4", position: 4, tenant: tenant)

      assert %{id: ^dummy_3, title: "subject", position: 3} =
               subject
               |> Dummy.update_changeset(tenant, %{"title" => "subject"})
               |> Repo.update!()

      assert [
               %{id: ^dummy_1, title: "1", position: 1},
               %{id: ^dummy_2, title: "2", position: 2},
               %{id: ^dummy_3, title: "subject", position: 3},
               %{id: ^dummy_4, title: "4", position: 4}
             ] = all_dummies!()
    end

    test "to a smaller one" do
      tenant = insert_tenant!()

      %{id: dummy_1} = insert_dummy!(title: "1", position: 1, tenant: tenant)
      %{id: dummy_2} = insert_dummy!(title: "2", position: 2, tenant: tenant)
      %{id: dummy_3} = subject = insert_dummy!(title: "3", position: 3, tenant: tenant)
      %{id: dummy_4} = insert_dummy!(title: "4", position: 4, tenant: tenant)

      assert %{id: ^dummy_3, title: "subject", position: 2} =
               subject
               |> Dummy.update_changeset(tenant, %{"title" => "subject", "position" => 2})
               |> Repo.update!()

      assert [
               %{id: ^dummy_1, title: "1", position: 1},
               %{id: ^dummy_3, title: "subject", position: 2},
               %{id: ^dummy_2, title: "2", position: 3},
               %{id: ^dummy_4, title: "4", position: 4}
             ] = all_dummies!()
    end

    test "to a bigger one" do
      tenant = insert_tenant!()

      %{id: dummy_1} = insert_dummy!(title: "1", position: 1, tenant: tenant)
      %{id: dummy_2} = subject = insert_dummy!(title: "2", position: 2, tenant: tenant)
      %{id: dummy_3} = insert_dummy!(title: "3", position: 3, tenant: tenant)
      %{id: dummy_4} = insert_dummy!(title: "4", position: 4, tenant: tenant)

      assert %{id: ^dummy_2, title: "subject", position: 3} =
               subject
               |> Dummy.update_changeset(tenant, %{"title" => "subject", "position" => 3})
               |> Repo.update!()

      assert [
               %{id: ^dummy_1, title: "1", position: 1},
               %{id: ^dummy_3, title: "3", position: 2},
               %{id: ^dummy_2, title: "subject", position: 3},
               %{id: ^dummy_4, title: "4", position: 4}
             ] = all_dummies!()
    end

    test "to a position way ahead of the collection" do
      tenant = insert_tenant!()

      %{id: dummy_1} = insert_dummy!(title: "1", position: 1, tenant: tenant)
      %{id: dummy_2} = subject = insert_dummy!(title: "2", position: 2, tenant: tenant)
      %{id: dummy_3} = insert_dummy!(title: "3", position: 3, tenant: tenant)
      %{id: dummy_4} = insert_dummy!(title: "4", position: 4, tenant: tenant)

      assert %{id: ^dummy_2, title: "subject", position: 4} =
               subject
               |> Dummy.update_changeset(tenant, %{"title" => "subject", "position" => 100})
               |> Repo.update!()

      assert [
               %{id: ^dummy_1, title: "1", position: 1},
               %{id: ^dummy_3, title: "3", position: 2},
               %{id: ^dummy_4, title: "4", position: 3},
               %{id: ^dummy_2, title: "subject", position: 4}
             ] = all_dummies!()
    end

    test "reorders both scopes if scope changed" do
      %{id: tenant_id} = tenant = insert_tenant!()
      %{id: another_tenant_id} = another_tenant = insert_tenant!()

      %{id: dummy_1} = insert_dummy!(title: "1", position: 1, tenant: tenant)
      %{id: dummy_2} = subject = insert_dummy!(title: "2", position: 2, tenant: tenant)
      %{id: dummy_3} = insert_dummy!(title: "3", position: 3, tenant: tenant)

      %{id: another_dummy_1} = insert_dummy!(title: "1", position: 1, tenant: another_tenant)
      %{id: another_dummy_2} = insert_dummy!(title: "2", position: 2, tenant: another_tenant)
      %{id: another_dummy_3} = insert_dummy!(title: "3", position: 3, tenant: another_tenant)

      assert %{id: ^dummy_2, title: "subject", position: 2, tenant_id: ^another_tenant_id} =
               subject
               |> Dummy.update_changeset(tenant, %{
                 "title" => "subject",
                 "position" => 2,
                 "tenant_id" => another_tenant_id
               })
               |> Repo.update!()

      assert [
               %{id: ^dummy_1, title: "1", position: 1, tenant_id: ^tenant_id},
               %{id: ^dummy_3, title: "3", position: 2, tenant_id: ^tenant_id},
               %{id: ^another_dummy_1, title: "1", position: 1, tenant_id: ^another_tenant_id},
               %{id: ^dummy_2, title: "subject", position: 2, tenant_id: ^another_tenant_id},
               %{id: ^another_dummy_2, title: "2", position: 3, tenant_id: ^another_tenant_id},
               %{id: ^another_dummy_3, title: "3", position: 4, tenant_id: ^another_tenant_id}
             ] = all_dummies!()
    end

    test "puts at the end of new scope if position specified" do
      %{id: tenant_id} = tenant = insert_tenant!()
      %{id: another_tenant_id} = another_tenant = insert_tenant!()

      %{id: dummy_1} = insert_dummy!(title: "1", position: 1, tenant: tenant)
      %{id: dummy_2} = subject = insert_dummy!(title: "2", position: 2, tenant: tenant)
      %{id: dummy_3} = insert_dummy!(title: "3", position: 3, tenant: tenant)

      %{id: another_dummy_1} = insert_dummy!(title: "1", position: 1, tenant: another_tenant)
      %{id: another_dummy_2} = insert_dummy!(title: "2", position: 2, tenant: another_tenant)
      %{id: another_dummy_3} = insert_dummy!(title: "3", position: 3, tenant: another_tenant)

      assert %{id: ^dummy_2, title: "subject", position: 4, tenant_id: ^another_tenant_id} =
               subject
               |> Dummy.update_changeset(tenant, %{
                 "title" => "subject",
                 "tenant_id" => another_tenant_id
               })
               |> Repo.update!()

      assert [
               %{id: ^dummy_1, title: "1", position: 1, tenant_id: ^tenant_id},
               %{id: ^dummy_3, title: "3", position: 2, tenant_id: ^tenant_id},
               %{id: ^another_dummy_1, title: "1", position: 1, tenant_id: ^another_tenant_id},
               %{id: ^another_dummy_2, title: "2", position: 2, tenant_id: ^another_tenant_id},
               %{id: ^another_dummy_3, title: "3", position: 3, tenant_id: ^another_tenant_id},
               %{id: ^dummy_2, title: "subject", position: 4, tenant_id: ^another_tenant_id}
             ] = all_dummies!()
    end
  end

  describe "Deleting record" do
    test "squeezes other records together" do
      tenant = insert_tenant!()

      %{id: dummy_1} = insert_dummy!(title: "1", position: 1, tenant: tenant)
      %{id: dummy_2} = insert_dummy!(title: "2", position: 2, tenant: tenant)
      %{id: dummy_3} = subject = insert_dummy!(title: "3", position: 3, tenant: tenant)
      %{id: dummy_4} = insert_dummy!(title: "4", position: 4, tenant: tenant)

      assert %{id: ^dummy_3, title: "3", position: 3} =
               subject
               |> Dummy.delete_changeset()
               |> Repo.delete!()

      assert [
               %{id: ^dummy_1, title: "1", position: 1},
               %{id: ^dummy_2, title: "2", position: 2},
               %{id: ^dummy_4, title: "4", position: 3}
             ] = all_dummies!()
    end

    test "doesn't affect other scopes" do
      tenant = insert_tenant!()
      another_tenant = insert_tenant!()

      %{id: dummy_1} = insert_dummy!(title: "1", position: 1, tenant: tenant)
      %{id: dummy_2} = insert_dummy!(title: "2", position: 2, tenant: tenant)
      %{id: dummy_3} = subject = insert_dummy!(title: "3", position: 3, tenant: tenant)
      %{id: dummy_4} = insert_dummy!(title: "4", position: 4, tenant: tenant)

      %{id: another_dummy_1} = insert_dummy!(title: "1", position: 1, tenant: another_tenant)
      %{id: another_dummy_2} = insert_dummy!(title: "2", position: 2, tenant: another_tenant)
      %{id: another_dummy_3} = insert_dummy!(title: "3", position: 3, tenant: another_tenant)

      assert %{id: ^dummy_3, title: "3", position: 3} =
               subject
               |> Dummy.delete_changeset()
               |> Repo.delete!()

      assert [
               %{id: ^dummy_1, title: "1", position: 1},
               %{id: ^dummy_2, title: "2", position: 2},
               %{id: ^dummy_4, title: "4", position: 3},
               %{id: ^another_dummy_1, title: "1", position: 1},
               %{id: ^another_dummy_2, title: "2", position: 2},
               %{id: ^another_dummy_3, title: "3", position: 3}
             ] = all_dummies!()
    end
  end
end
