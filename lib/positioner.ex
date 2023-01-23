defmodule Positioner do
  import Ecto.Query

  @moduledoc """
  Lower level API for keeping your collection ordered.

  It provides a set of functions that will reorder the collection as if the operation
  you are going to perform (insert/update/delete) was already performed.

  This means that this module will make sure to make a vacant space for you new records
  at the position you want it to, or will remove any holes in ordering due to moving and
  deleting records.

  In addition it provides a function to reorder your whole collection which comes in hand
  with drag and drop

  If your collection gets out of sync you can use `refresh_order!/3` to reorder it again
  """

  @typedoc "Database primary key"
  @type id :: integer()
  @typedoc "Module with Ecto.Schema to be ordered"
  @type model :: module()
  @typedoc "List of keys shared by the collection"
  @type scopes :: keyword({atom(), any()})
  @typedoc "Name of the field that holds the position"
  @type position_field :: atom()
  @typedoc "Position value"
  @type position :: integer()

  @doc """
  Calculates the position for new record in a given scope.
  It's either 1 if there are no records or end of the scope.

  Example:
      iex> Positioner.position_for_new(Dummy, [tenant_id: tenant_id], :position)
      1
      iex> Positioner.position_for_new(Dummy, [tenant_id: tenant_id], :position)
      2
      iex> Positioner.position_for_new(Dummy, [tenant_id: another_tenant_id], :position)
      1
  """
  @spec position_for_new(model(), scopes(), position_field()) :: position()
  def position_for_new(schema_module, scopes \\ [], field_name \\ :position) do
    schema_module
    |> from(as: :source)
    |> scope_query(scopes)
    |> select([source: s], max(field(s, ^field_name)))
    |> Positioner.Config.repo().one()
    |> case do
      nil -> 1
      highest_position -> highest_position + 1
    end
  end

  @doc """
  Spreads the records in collection as if new record at `position` was inserted, making it safe to insert a new record

  Example:
      # Assume records:
      #  %Dummy{id: 1, tenant_id: 1, position: 1}
      #  %Dummy{id: 2, tenant_id: 1, position: 2}
      #  %Dummy{id: 3, tenant_id: 1, position: 3}
      iex> Positioner.insert_at(Dummy, [tenant_id: 1], :position, 2)
      :ok
      #  %Dummy{id: 1, tenant_id: 1, position: 1}
      #  %Dummy{id: 2, tenant_id: 1, position: 3}
      #  %Dummy{id: 3, tenant_id: 1, position: 4}
  """
  @spec insert_at(model(), scopes(), position_field(), position()) :: :ok
  def insert_at(schema_module, scopes \\ [], field_name \\ :position, position)
      when is_atom(field_name) and is_integer(position) do
    # Step 1:
    # Create a query of all current records + a fake records at given position
    all_records = all_records_query(schema_module, scopes, field_name)
    fake_new_record = fake_record_query(position)
    fake_table = union(all_records, ^fake_new_record)

    # Step 2:
    # Order the fake table
    ordering_query = ordered_query(fake_table)

    # Step 3:
    # Update all records that have different position than the one in ordered fake table
    final_query = final_query(schema_module, ordering_query, field_name)
    Positioner.Config.repo().update_all(final_query, [])

    :ok
  end

  @doc """
  Adjusts collection as if the record with `id` was moved to a different position,
  making it safe to update the record

  Example:
      # Assume records:
      #  %Dummy{id: 1, tenant_id: 1, position: 1}
      #  %Dummy{id: 2, tenant_id: 1, position: 2}
      #  %Dummy{id: 3, tenant_id: 1, position: 3}
      #  %Dummy{id: 4, tenant_id: 1, position: 4}
      iex> Positioner.insert_at(Dummy, [tenant_id: 1], :position, 2, 3, 2)
      :ok
      #  %Dummy{id: 1, tenant_id: 1, position: 1}
      #  %Dummy{id: 2, tenant_id: 1, position: 2}
      #  %Dummy{id: 3, tenant_id: 1, position: 2}
      #  %Dummy{id: 4, tenant_id: 1, position: 4}
  """
  @spec update_to(model(), scopes(), position_field(), position(), position(), id()) :: :ok
  def update_to(
        schema_module,
        scopes \\ [],
        field_name \\ :position,
        current_position,
        position,
        id
      )
      when is_atom(field_name) and is_integer(position) and is_integer(id) do
    # Step 1:
    # Create a query of all current records without the one being updated
    all_records = all_records_without_query(schema_module, scopes, field_name, id)

    # Step 2:
    # We need to create a fake record at given position.
    # When moving the record past the current position we
    # need to compensate for the missing record.
    #
    # --- Moving b -> 3 (incorrect)
    # record:   | a b c d -> a c d -> a c d _ -> a _ c d -> a _ c d
    # position: | 1 2 3 4    1 3 4 -> 1 3 4 3    1 3 3 4    1 2 3 4
    #
    # --- Moving b -> 3 (compensated)
    # record:   | a b c d -> a c d -> a c d _ -> a c _ d -> a c _ d
    # position: | 1 2 3 4    1 3 4 -> 1 3 4 4    1 3 4 4    1 2 3 4
    #
    # --- Moving c -> 2
    # record:   | a b c d -> a b d -> a b d _ -> a _ b d -> a _ b d
    # position: | 1 2 3 4    1 2 4 -> 1 2 4 2    1 2 2 4    1 2 3 4

    new_position =
      if not is_nil(current_position) and current_position < position do
        position + 1
      else
        position
      end

    # Step 3:
    # Get a table of all records without updated one and simulate new fake record at updated position
    fake_record_query = fake_record_query(new_position)

    fake_table = union(all_records, ^fake_record_query)

    # Step 4:
    # Order the fake table
    ordering_query = ordered_query(fake_table)

    # Step 5:
    # Update all records that have different position than the one in ordered fake table
    final_query = final_without_query(schema_module, ordering_query, field_name, id)

    Positioner.Config.repo().update_all(final_query, [])

    :ok
  end

  @doc """
  Readjusts collection fields as if record with `id` was deleted, making it safe to delete.

  Example:
      # Assume records:
      #  %Dummy{id: 1, tenant_id: 1, position: 1}
      #  %Dummy{id: 2, tenant_id: 1, position: 2}
      #  %Dummy{id: 3, tenant_id: 1, position: 3}
      iex> Positioner.delete(Dummy, [tenant_id: 1], :position, 2)
      :ok
      #  %Dummy{id: 1, tenant_id: 1, position: 1}
      #  %Dummy{id: 2, tenant_id: 1, position: 2}
      #  %Dummy{id: 3, tenant_id: 1, position: 2}
  """
  @spec delete(model(), scopes(), position_field(), id()) :: :ok
  def delete(schema_module, scopes \\ [], field_name \\ :position, id)
      when is_atom(field_name) and is_integer(id) do
    # Step 1:
    # Get all records without the one we want to delete
    all_records_without_ours = all_records_without_query(schema_module, scopes, field_name, id)
    # Step 2:
    # Order the table above
    ordering_query = ordered_query(all_records_without_ours)

    # Step 3:
    # Update all records that have different position than the one in ordered table
    final_query = final_without_query(schema_module, ordering_query, field_name, id)
    Positioner.Config.repo().update_all(final_query, [])

    :ok
  end

  @doc """
  Reorders the collection according to the order in `ids` argument list.

  Records that belong to collection but were not passed to the list will be moved
  to the end of the collection keeping their current order


  Example:
      # Assume records:
      #  %Dummy{id: 1, tenant_id: 1, position: 1}
      #  %Dummy{id: 2, tenant_id: 1, position: 2}
      #  %Dummy{id: 3, tenant_id: 1, position: 3}
      #  %Dummy{id: 4, tenant_id: 1, position: 4}
      iex> Positioner.update_positions(Dummy, [tenant_id: 1], :position, [4, 3])
      :ok
      #  %Dummy{id: 1, tenant_id: 1, position: 3}
      #  %Dummy{id: 2, tenant_id: 1, position: 4}
      #  %Dummy{id: 3, tenant_id: 1, position: 2}
      #  %Dummy{id: 4, tenant_id: 1, position: 1}
  """
  @spec update_positions!(model(), scopes(), position_field(), list(id())) :: :ok
  def update_positions!(schema_module, scopes \\ [], field_name \\ :position, ids)
      when is_list(ids) and is_atom(field_name) do
    all_records = all_records_query(schema_module, scopes, field_name)

    ordered_query =
      ordered_query_base(all_records)
      |> windows([collection: c],
        expected_position_window: [
          order_by: [
            asc_nulls_last: fragment("array_position(?::bigint[], ?::bigint)", ^ids, c.id),
            asc: c.position,
            desc_nulls_last: c.updated_at,
            asc: c.id
          ]
        ]
      )

    final_query = final_query(schema_module, ordered_query, field_name)
    Positioner.Config.repo().update_all(final_query, [])

    :ok
  end

  @doc """
  Reorders the record that might have lost its ordering.
  Will remove holes in ordering. On conflict, records with the same position
  will be ordered according to their `updated_at` and `id`  columns

  Example:
      # Assume records:
      #  %Dummy{id: 1, tenant_id: 1, position: 1}
      #  %Dummy{id: 2, tenant_id: 1, position: 2}
      #  %Dummy{id: 3, tenant_id: 1, position: 6}
      #  %Dummy{id: 4, tenant_id: 1, position: 6}
      iex> Positioner.update_positions(Dummy, [tenant_id: 1], :position, [4, 3])
      :ok
      #  %Dummy{id: 1, tenant_id: 1, position: 1}
      #  %Dummy{id: 2, tenant_id: 1, position: 2}
      #  %Dummy{id: 3, tenant_id: 1, position: 3}
      #  %Dummy{id: 4, tenant_id: 1, position: 4}
  """
  @spec refresh_order!(model(), scopes(), position_field()) :: :ok
  def refresh_order!(schema_module, scopes \\ [], field_name \\ :position) do
    all_records = all_records_query(schema_module, scopes, field_name)
    ordered_query = ordered_query(all_records)
    final_query = final_query(schema_module, ordered_query, field_name)

    Positioner.Config.repo().update_all(final_query, [])

    :ok
  end

  defp scope_query(query, scope) do
    {nil_clauses, non_nil_clauses} =
      Enum.split_with(scope, fn
        {_, nil} -> true
        _ -> false
      end)

    nil_clauses
    |> Enum.reduce(query, fn {field_name, _}, query ->
      where(query, [q], is_nil(field(q, ^field_name)))
    end)
    |> where(^non_nil_clauses)
  end

  defp all_records_query(schema_module, scopes, field_name) when is_atom(field_name) do
    schema_module
    |> from(as: :source)
    |> scope_query(scopes)
    |> select([source: s], %{
      id: s.id,
      position: field(s, ^field_name),
      updated_at: s.updated_at
    })
  end

  defp all_records_without_query(schema_module, scopes, field_name, id)
       when is_atom(field_name) and is_integer(id) do
    schema_module
    |> all_records_query(scopes, field_name)
    |> where([source: s], s.id != ^id)
  end

  defp fake_record_query(position) when is_integer(position) do
    "fake"
    |> with_cte("fake",
      as:
        fragment(
          ~s[SELECT 0 as "id", ?::integer as "position", NOW() + INTERVAL '1 day' as "updated_at"],
          ^position
        )
    )
    |> select([fake], %{id: fake.id, position: fake.position, updated_at: fake.updated_at})
  end

  defp ordered_query(fake_table) do
    fake_table
    |> ordered_query_base()
    |> windows([collection: c],
      expected_position_window: [
        order_by: [asc: c.position, desc_nulls_last: c.updated_at, asc: c.id]
      ]
    )
  end

  defp ordered_query_base(fake_table) do
    fake_table
    |> subquery()
    |> from(as: :collection)
    |> select([collection: c], %{
      id: c.id,
      current_position: coalesce(c.position, 0),
      expected_position: row_number() |> over(:expected_position_window)
    })
  end

  defp final_query(schema_module, ordered_query, field_name) do
    schema_module
    |> from(as: :source)
    |> join(:inner, [source: s], o in subquery(ordered_query),
      on: s.id == o.id and o.id != 0 and o.current_position != o.expected_position,
      as: :ordering
    )
    |> update([source: s, ordering: o], set: [{^field_name, o.expected_position}])
  end

  defp final_without_query(schema_module, ordered_query, field_name, id) do
    schema_module
    |> final_query(ordered_query, field_name)
    |> where([source: s], s.id != ^id)
  end
end
