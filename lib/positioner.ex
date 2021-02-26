defmodule Positioner do
  import Ecto.Query

  @doc """
  Calculates the position for new record in a given scope.
  It's either 1 if there are no records or end of the scope.

  Example:
      iex> Positioner.positioner_for_new(Dummy, [tenant_id: tenant_id], :position)
      1
      iex> Positioner.positioner_for_new(Dummy, [tenant_id: tenant_id], :position)
      2
      iex> Positioner.positioner_for_new(Dummy, [tenant_id: another_tenant_id], :position)
      1
  """
  @spec position_for_new(Ecto.Schema.t(), keyword(), atom()) :: integer()
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

  @spec insert_at(Ecto.Schema.t(), keyword(), atom(), integer()) :: :ok
  def insert_at(schema_module, scopes \\ [], field_name \\ :position, position)
      when is_atom(field_name) and is_integer(position) do
    # Step 1:
    # Create a query of all current records + a fake records at given position
    all_records = all_records_query(schema_module, scopes, field_name)
    fake_new_record = fake_record_query(schema_module, position)
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

  @spec update_to(Ecto.Schema.t(), keyword(), atom(), integer(), integer()) :: :ok
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
    fake_record_query = fake_record_query(schema_module, new_position)
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

  @spec refresh_order!(module(), Keyword.t(), atom()) :: :ok
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

  defp fake_record_query(schema_module, position) when is_integer(position) do
    schema_module
    |> from(as: :source)
    |> select(%{
      id: fragment(~s[? as "id"], 0),
      position: fragment(~s[? as "position"], ^position),
      updated_at: fragment(~s[NOW() + INTERVAL '1 day' as "updated_at"])
    })
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
      on: s.id == o.id and o.id != 0,
      as: :ordering
    )
    |> where([source: s, ordering: o], o.current_position != o.expected_position)
    |> update([source: s, ordering: o], set: [{^field_name, o.expected_position}])
  end

  def final_without_query(schema_module, ordered_query, field_name, id) do
    schema_module
    |> final_query(ordered_query, field_name)
    |> where([source: s], s.id != ^id)
  end
end
