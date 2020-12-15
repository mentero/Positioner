defmodule Positioner do
  import Ecto.Query
  alias Ecto.Adapters.SQL

  @repo Positioner.Repo

  @spec position_for_new(Ecto.Schema.t(), keyword(), atom()) :: integer()
  def position_for_new(schema_module, scopes \\ [], field_name \\ :position) do
    schema_module
    |> from(as: :source)
    |> scope_query(scopes)
    |> select([source: s], max(field(s, ^field_name)))
    |> @repo.one()
    |> case do
      nil -> 1
      highest_position -> highest_position + 1
    end
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
    source = schema_module.__schema__(:source)

    siblings_query =
      schema_module
      |> from(as: :source)
      |> scope_query(scopes)
      |> select([source: s], [s.id, field(s, ^field_name), s.updated_at])

    {siblings_query_string, siblings_params} = @repo.to_sql(:all, siblings_query)

    params_offset = Enum.count(siblings_params)

    sql = """
      UPDATE #{source}
      SET #{field_name} = ordering.expected_position
      FROM (
        SELECT "id", "position", row_number() OVER (ORDER BY #{field_name} ASC, "updated_at" DESC NULLS LAST) AS "expected_position"
        FROM (
          (#{siblings_query_string})
          UNION
          (SELECT 0 as "id", $#{1 + params_offset} as "#{field_name}", NOW() as "updated_at")
        ) AS collection
      ) AS ordering(id, current_position, expected_position)
      WHERE #{source}.id = ordering.id AND #{source}.id <> 0 AND coalesce(ordering.current_position, 0) <> ordering.expected_position
    """

    SQL.query!(@repo, sql, siblings_params ++ [position])

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
