defmodule Positioner do
  import Ecto.Query
  alias Ecto.Adapters.SQL

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

  defp siblings_query(schema_module, scopes, field_name) when is_atom(field_name) do
    schema_module
    |> from(as: :source)
    |> scope_query(scopes)
    |> select([source: s], %{
      id: s.id,
      position: field(s, ^field_name),
      updated_at: s.updated_at
    })
  end

  @doc """
  How it works:
    This query is build from few parts

    1. We select all current records that match defined scope and call it siblings
       The values for each record that we are interested in are:
       - id
       - position
       - update_at
    2. We create a union (let's call it `union`) with a fake row
       that is representing the records we want to add and we set it's
       - id => 0,
       - position => value from params
       - updated_at => current time
    3. We use window function to assign a `row number` to each record from the `union`
       sorted their position and updated_at. We get the `ordering` table with values as
       - id
       - current_position
       - expected_position (from row_number)
    4. We use the `ordering` to update all the records that have `current_position` not matching it's
       `expected_position`, ignoring the row with `id = 0` since it was just a placeholder

    After these steps we have a collection where all positions are ordered and there is a slot for a new record
    at a position that we asked in params
  """
  @spec insert_at(Ecto.Schema.t(), keyword(), atom(), integer()) :: :ok
  def insert_at(schema_module, scopes \\ [], field_name \\ :position, position)
      when is_atom(field_name) and is_integer(position) do
    siblings_query = siblings_query(schema_module, scopes, field_name)

    fake_record_query =
      schema_module
      |> from(as: :source)
      |> select(%{
        id: fragment(~s[? as "id"], 0),
        position: fragment(~s[? as "position"], ^position),
        updated_at: fragment(~s[NOW() + INTERVAL '1 day' as "updated_at"])
      })

    collection = union(siblings_query, ^fake_record_query)

    ordering_query =
      collection
      |> subquery()
      |> from(as: :collection)
      |> select([collection: c], %{
        id: c.id,
        current_position: coalesce(c.position, 0),
        expected_position:
          row_number()
          |> over(order_by: [asc: c.position, desc_nulls_last: c.updated_at, asc: c.id])
      })

    final_query =
      schema_module
      |> from(as: :source)
      |> join(:inner, [source: s], o in subquery(ordering_query),
        on: s.id == o.id and o.id != 0,
        as: :ordering
      )
      |> where([source: s, ordering: o], o.current_position != o.expected_position)
      |> update([source: s, ordering: o], set: [{^field_name, o.expected_position}])

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
    # source = schema_module.__schema__(:source)

    siblings_query =
      schema_module
      |> from(as: :source)
      |> scope_query(scopes)
      |> where([source: s], s.id != ^id)

    {siblings_query_string, siblings_params} =
      Positioner.Config.repo().to_sql(:all, siblings_query)

    params_offset = Enum.count(siblings_params)

    new_position =
      if not is_nil(current_position) and current_position < position do
        position + 1
      else
        position
      end

    sql = """
      UPDATE #{source}
      SET #{field_name} = ordering.expected_position
      FROM (
        SELECT
          collection."id",
          collection."#{field_name}",
          row_number() OVER (ORDER BY collection.#{field_name} ASC, collection."updated_at" DESC NULLS LAST) AS "expected_position"
        FROM (
          (#{siblings_query_string})
          UNION
          (SELECT $#{params_offset} as "id", $#{1 + params_offset} as "#{field_name}", NOW() + INTERVAL '1 day' as "updated_at")
        ) AS collection
      ) AS ordering(id, current_position, expected_position)
      WHERE #{source}.id = ordering.id AND #{source}.id <> $#{params_offset} AND coalesce(ordering.current_position, 0) <> ordering.expected_position
    """

    SQL.query!(Positioner.Config.repo(), sql, siblings_params ++ [new_position])

    :ok
  end

  def delete(schema_module, scopes \\ [], field_name \\ :position, id)
      when is_atom(field_name) and is_integer(id) do
    source = schema_module.__schema__(:source)

    siblings_query =
      schema_module
      |> from(as: :source)
      |> scope_query(scopes)
      |> where([source: s], s.id != ^id)
      |> select([source: s], [s.id, field(s, ^field_name), s.updated_at])

    {siblings_query_string, siblings_params} =
      Positioner.Config.repo().to_sql(:all, siblings_query)

    params_offset = Enum.count(siblings_params)

    sql = """
      UPDATE #{source}
      SET #{field_name} = ordering.expected_position
      FROM (
        SELECT "id", "#{field_name}", row_number() OVER (ORDER BY #{field_name} ASC, "updated_at" DESC NULLS LAST) AS "expected_position"
        FROM (#{siblings_query_string}) AS collection
      ) AS ordering(id, current_position, expected_position)
      WHERE #{source}.id = ordering.id AND #{source}.id <> $#{params_offset} AND coalesce(ordering.current_position, 0) <> ordering.expected_position
    """

    SQL.query!(Positioner.Config.repo(), sql, siblings_params)

    :ok
  end

  def update_positions!(schema_module, scopes \\ [], field_name \\ :position, ids)
      when is_list(ids) and is_atom(field_name) do
    source = schema_module.__schema__(:source)

    subquery =
      source
      |> from(as: :source)
      |> scope_query(scopes)
      |> select([source: s], %{
        id: s.id,
        current_position: field(s, ^field_name),
        expected_position: row_number() |> over(:expected_position_window)
      })
      |> windows([source: s],
        expected_position_window: [
          order_by: [
            asc_nulls_last: fragment("array_position(?::bigint[], ?::bigint)", ^ids, s.id),
            asc: field(s, ^field_name)
          ]
        ]
      )

    {subquery_string, subquery_params} = Positioner.Config.repo().to_sql(:all, subquery)

    SQL.query!(
      Positioner.Config.repo(),
      """
      UPDATE #{source}
      SET #{field_name} = ordering.expected_position
      FROM(#{subquery_string}) as ordering(id, current_position, expected_position)
      WHERE #{source}.id = ordering.id AND coalesce(ordering.current_position, 0) <> ordering.expected_position
      RETURNING #{source}.*;
      """,
      subquery_params
    )

    :ok
  end

  @spec refresh_order!(module(), Keyword.t(), atom()) :: :ok
  def refresh_order!(schema_module, scopes \\ [], field_name \\ :position) do
    source = schema_module.__schema__(:source)

    subquery =
      source
      |> from(as: :source)
      |> scope_query(scopes)
      |> select([source: s], %{
        id: s.id,
        current_position: field(s, ^field_name),
        expected_position: row_number() |> over(:expected_position_window)
      })
      |> windows([source: s],
        expected_position_window: [order_by: [asc: field(s, ^field_name), desc: s.updated_at]]
      )

    {subquery_string, subquery_params} = Positioner.Config.repo().to_sql(:all, subquery)

    SQL.query!(
      Positioner.Config.repo(),
      """
      UPDATE #{source}
      SET #{field_name} = ordering.expected_position
      FROM(#{subquery_string}) as ordering(id, current_position, expected_position)
      WHERE #{source}.id = ordering.id AND coalesce(ordering.current_position, 0) <> ordering.expected_position
      RETURNING #{source}.*;
      """,
      subquery_params
    )

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
end
