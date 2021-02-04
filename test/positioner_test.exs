defmodule PositionerTest do
  use Positioner.TestCase

  import Positioner.TestHelpers

  describe "position_for_new" do
    test "there are no records in a scope" do
      %{id: tenant_id} = insert_tenant!()

      assert 1 = Positioner.position_for_new(Dummy, [tenant_id: tenant_id], :position)
    end

    test "there are several records in a scope" do
      %{id: tenant_id} = tenant = insert_tenant!()

      insert_dummy!(tenant: tenant, position: 1)
      insert_dummy!(tenant: tenant, position: 2)

      assert 3 = Positioner.position_for_new(Dummy, [tenant_id: tenant_id], :position)
    end

    test "adding to another scope" do
      tenant = insert_tenant!()
      %{id: another_tenant_id} = insert_tenant!()

      insert_dummy!(tenant: tenant, position: 1)
      insert_dummy!(tenant: tenant, position: 2)

      assert 1 = Positioner.position_for_new(Dummy, [tenant_id: another_tenant_id], :position)
    end
  end

  describe "insert_at" do
    test "in the beginning" do
      %{id: tenant_id} = tenant = insert_tenant!()

      %{id: d1} = insert_dummy!(position: 1, tenant: tenant)
      %{id: d2} = insert_dummy!(position: 2, tenant: tenant)
      %{id: d3} = insert_dummy!(position: 3, tenant: tenant)
      %{id: d4} = insert_dummy!(position: 4, tenant: tenant)

      Positioner.insert_at(Dummy, [tenant_id: tenant_id], :position, 1)

      assert [
               %{id: ^d1, position: 2},
               %{id: ^d2, position: 3},
               %{id: ^d3, position: 4},
               %{id: ^d4, position: 5}
             ] = all_dummies!()
    end

    test "in the middle" do
      %{id: tenant_id} = tenant = insert_tenant!()

      %{id: d1} = insert_dummy!(position: 1, tenant: tenant)
      %{id: d2} = insert_dummy!(position: 2, tenant: tenant)
      %{id: d3} = insert_dummy!(position: 3, tenant: tenant)
      %{id: d4} = insert_dummy!(position: 4, tenant: tenant)

      Positioner.insert_at(Dummy, [tenant_id: tenant_id], :position, 3)

      assert [
               %{id: ^d1, position: 1},
               %{id: ^d2, position: 2},
               %{id: ^d3, position: 4},
               %{id: ^d4, position: 5}
             ] = all_dummies!()
    end

    test "at the end" do
      %{id: tenant_id} = tenant = insert_tenant!()

      %{id: d1} = insert_dummy!(position: 1, tenant: tenant)
      %{id: d2} = insert_dummy!(position: 2, tenant: tenant)
      %{id: d3} = insert_dummy!(position: 3, tenant: tenant)
      %{id: d4} = insert_dummy!(position: 4, tenant: tenant)

      Positioner.insert_at(Dummy, [tenant_id: tenant_id], :position, 5)

      assert [
               %{id: ^d1, position: 1},
               %{id: ^d2, position: 2},
               %{id: ^d3, position: 3},
               %{id: ^d4, position: 4}
             ] = all_dummies!()
    end

    test "multiple scopes" do
      %{id: d1} = insert_dummy!(position: 1, title: "A")
      %{id: d2} = insert_dummy!(position: 2, title: "A")
      %{id: d3} = insert_dummy!(position: 3, title: "A")
      %{id: d4} = insert_dummy!(position: 4, title: "A")
      %{id: d5} = insert_dummy!(position: 1, title: "B")
      %{id: d6} = insert_dummy!(position: 2, title: "B")

      Positioner.insert_at(Dummy, [title: "A"], :position, 3)

      assert [
               %{id: ^d1, position: 1, title: "A"},
               %{id: ^d2, position: 2, title: "A"},
               %{id: ^d3, position: 4, title: "A"},
               %{id: ^d4, position: 5, title: "A"},
               %{id: ^d5, position: 1, title: "B"},
               %{id: ^d6, position: 2, title: "B"}
             ] = all_dummies!()
    end

    test "different field" do
      %{id: tenant_id} = tenant = insert_tenant!()

      %{id: d1} = insert_dummy!(position: 1, idx: 1, tenant: tenant)
      %{id: d2} = insert_dummy!(position: 2, idx: 2, tenant: tenant)
      %{id: d3} = insert_dummy!(position: 3, idx: 3, tenant: tenant)
      %{id: d4} = insert_dummy!(position: 4, idx: 4, tenant: tenant)

      Positioner.insert_at(Dummy, [tenant_id: tenant_id], :idx, 3)

      assert [
               %{id: ^d1, position: 1, idx: 1},
               %{id: ^d2, position: 2, idx: 2},
               %{id: ^d3, position: 3, idx: 4},
               %{id: ^d4, position: 4, idx: 5}
             ] = all_dummies!()
    end
  end

  describe "update_to" do
    test "move forward" do
      %{id: tenant_id} = tenant = insert_tenant!()

      %{id: d1} = insert_dummy!(position: 1, tenant: tenant)
      %{id: to_be_3} = insert_dummy!(position: 2, tenant: tenant)
      %{id: d3} = insert_dummy!(position: 3, tenant: tenant)
      %{id: d4} = insert_dummy!(position: 4, tenant: tenant)

      Positioner.update_to(Dummy, [tenant_id: tenant_id], :position, 2, 3, to_be_3)

      assert [
               %{id: ^d1, position: 1},
               %{id: ^to_be_3, position: 2},
               %{id: ^d3, position: 2},
               %{id: ^d4, position: 4}
             ] = all_dummies!()
    end

    test "move backwards" do
      %{id: tenant_id} = tenant = insert_tenant!()

      %{id: d1} = insert_dummy!(position: 1, tenant: tenant)
      %{id: d2} = insert_dummy!(position: 2, tenant: tenant)
      %{id: to_be_2} = insert_dummy!(position: 3, tenant: tenant)
      %{id: d4} = insert_dummy!(position: 4, tenant: tenant)

      Positioner.update_to(Dummy, [tenant_id: tenant_id], :position, 3, 2, to_be_2)

      assert [
               %{id: ^d1, position: 1},
               %{id: ^to_be_2, position: 3},
               %{id: ^d2, position: 3},
               %{id: ^d4, position: 4}
             ] = all_dummies!()
    end

    test "different field" do
      %{id: tenant_id} = tenant = insert_tenant!()

      %{id: d1} = insert_dummy!(position: 1, idx: 1, tenant: tenant)
      %{id: to_be_3} = insert_dummy!(position: 2, idx: 2, tenant: tenant)
      %{id: d3} = insert_dummy!(position: 3, idx: 3, tenant: tenant)
      %{id: d4} = insert_dummy!(position: 4, idx: 4, tenant: tenant)

      Positioner.update_to(Dummy, [tenant_id: tenant_id], :idx, 2, 3, to_be_3)

      assert [
               %{id: ^d1, position: 1, idx: 1},
               %{id: ^to_be_3, position: 2, idx: 2},
               %{id: ^d3, position: 3, idx: 2},
               %{id: ^d4, position: 4, idx: 4}
             ] = all_dummies!()
    end
  end

  describe "delete" do
    test "from the middle" do
      %{id: tenant_id} = tenant = insert_tenant!()

      %{id: d1} = insert_dummy!(position: 1, tenant: tenant)
      %{id: d2} = insert_dummy!(position: 2, tenant: tenant)
      %{id: to_be_removed} = insert_dummy!(position: 3, tenant: tenant)
      %{id: d4} = insert_dummy!(position: 4, tenant: tenant)

      Positioner.delete(Dummy, [tenant_id: tenant_id], :position, to_be_removed)

      assert [
               %{id: ^d1, position: 1},
               %{id: ^d2, position: 2},
               %{id: ^to_be_removed, position: 3},
               %{id: ^d4, position: 3}
             ] = all_dummies!()
    end
  end

  describe "update_positions!" do
    test "reorders records based on positions" do
      %{id: tenant_id} = tenant = insert_tenant!()

      %{id: d1} = insert_dummy!(position: 1, tenant: tenant)
      %{id: d2} = insert_dummy!(position: 2, tenant: tenant)
      %{id: d3} = insert_dummy!(position: 3, tenant: tenant)
      %{id: d4} = insert_dummy!(position: 4, tenant: tenant)

      Positioner.update_positions!(Dummy, [tenant_id: tenant_id], :position, [d3, d4, d2, d1])

      assert [
               %{id: ^d3, position: 1},
               %{id: ^d4, position: 2},
               %{id: ^d2, position: 3},
               %{id: ^d1, position: 4}
             ] = all_dummies!()
    end

    test "records not in params are pushed to the end" do
      %{id: tenant_id} = tenant = insert_tenant!()

      %{id: d1} = insert_dummy!(position: 1, tenant: tenant)
      %{id: d2} = insert_dummy!(position: 2, tenant: tenant)
      %{id: d3} = insert_dummy!(position: 3, tenant: tenant)
      %{id: d4} = insert_dummy!(position: 4, tenant: tenant)

      Positioner.update_positions!(Dummy, [tenant_id: tenant_id], :position, [d4, d3])

      assert [
               %{id: ^d4, position: 1},
               %{id: ^d3, position: 2},
               %{id: ^d1, position: 3},
               %{id: ^d2, position: 4}
             ] = all_dummies!()
    end

    test "ignores records out of scope" do
      %{id: tenant_id} = tenant = insert_tenant!()
      another_tenant = insert_tenant!()

      %{id: d1} = insert_dummy!(position: 1, tenant: tenant)
      %{id: d2} = insert_dummy!(position: 2, tenant: tenant)
      %{id: d3} = insert_dummy!(position: 3, tenant: tenant)
      %{id: d4} = insert_dummy!(position: 4, tenant: tenant)

      %{id: ad1} = insert_dummy!(position: 1, tenant: another_tenant)
      %{id: ad2} = insert_dummy!(position: 2, tenant: another_tenant)
      %{id: ad3} = insert_dummy!(position: 3, tenant: another_tenant)
      %{id: ad4} = insert_dummy!(position: 4, tenant: another_tenant)

      params = [d1, ad1, d2, ad2, d4, ad4, d3, ad3]

      Positioner.update_positions!(Dummy, [tenant_id: tenant_id], :position, params)

      assert [
               %{id: ^d1, position: 1},
               %{id: ^d2, position: 2},
               %{id: ^d4, position: 3},
               %{id: ^d3, position: 4},
               %{id: ^ad1, position: 1},
               %{id: ^ad2, position: 2},
               %{id: ^ad3, position: 3},
               %{id: ^ad4, position: 4}
             ] = all_dummies!()
    end

    test "reorders a field other than position" do
      %{id: tenant_id} = tenant = insert_tenant!()

      %{id: d1} = insert_dummy!(position: 1, idx: 4, tenant: tenant)
      %{id: d2} = insert_dummy!(position: 2, idx: 3, tenant: tenant)
      %{id: d3} = insert_dummy!(position: 3, idx: 2, tenant: tenant)
      %{id: d4} = insert_dummy!(position: 4, idx: 1, tenant: tenant)

      Positioner.update_positions!(Dummy, [tenant_id: tenant_id], :idx, [d2, d3, d1, d4])

      assert [
               %{id: ^d1, position: 1, idx: 3},
               %{id: ^d2, position: 2, idx: 1},
               %{id: ^d3, position: 3, idx: 2},
               %{id: ^d4, position: 4, idx: 4}
             ] = all_dummies!()
    end
  end

  describe "refresh_order!" do
    test "reorders records to fill gaps and remove duplicated positions" do
      %{id: tenant_id} = tenant = insert_tenant!()

      %{id: dummy_1} = insert_dummy!(position: 9, tenant: tenant)

      %{id: dummy_2} =
        insert_dummy!(
          position: 3,
          tenant: tenant,
          updated_at: ~N[2020-01-01 12:00:00]
        )

      %{id: dummy_3} =
        insert_dummy!(
          position: 3,
          tenant: tenant,
          updated_at: ~N[2020-01-01 12:01:01]
        )

      %{id: dummy_4} = insert_dummy!(position: 1, tenant: tenant)

      Positioner.refresh_order!(Dummy, [tenant_id: tenant_id], :position)

      assert [
               %{id: ^dummy_4, position: 1},
               %{id: ^dummy_3, position: 2},
               %{id: ^dummy_2, position: 3},
               %{id: ^dummy_1, position: 4}
             ] = all_dummies!()
    end
  end
end
