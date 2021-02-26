defmodule Positioner.Changeset do
  import Ecto.Changeset

  @spec set_order(Ecto.Changeset.t(), atom(), list(atom()) | atom()) :: Ecto.Changeset.t()
  def set_order(changeset, field_name \\ :position, scopes \\ [])

  def set_order(changeset, field_name, scopes) when not is_list(scopes) do
    set_order(changeset, field_name, List.wrap(scopes))
  end

  def set_order(changeset, field_name, scopes) do
    prepare_changes(changeset, fn changeset ->
      model_name = fetch_field!(changeset, :__struct__)
      collection_scope_params = collection_scope(changeset, scopes)

      case changeset.action do
        :insert -> on_insert(changeset, model_name, collection_scope_params, field_name)
        :update -> on_update(changeset, model_name, collection_scope_params, scopes, field_name)
        :delete -> on_delete(changeset, model_name, collection_scope_params, field_name)
      end
    end)
  end

  defp on_insert(changeset, model_name, collection_scope, field_name) do
    given_position = get_change(changeset, field_name)
    max_position = Positioner.position_for_new(model_name, collection_scope, field_name)

    insert_position =
      if is_nil(given_position) or given_position > max_position do
        max_position
      else
        given_position
      end

    Positioner.insert_at(model_name, collection_scope, field_name, insert_position)
    changeset |> put_change(field_name, insert_position)
  end

  defp on_update(changeset, model_name, collection_scope, scopes, field_name) do
    cond do
      scope_changed?(changeset, scopes) ->
        update_to_different_scope(changeset, model_name, collection_scope, scopes, field_name)

      position_changed?(changeset, field_name) ->
        update_same_scope(changeset, model_name, collection_scope, field_name)

      true ->
        changeset
    end
  end

  defp on_delete(%{data: %{id: id}} = changeset, model_name, collection_scope, field_name) do
    Positioner.delete(model_name, collection_scope, field_name, id)
    changeset
  end

  defp update_to_different_scope(changeset, model_name, collection_scope, scopes, field_name) do
    id = fetch_field!(changeset, :id)
    max_position = Positioner.position_for_new(model_name, collection_scope, field_name)
    given_position = fetch_field!(changeset, field_name)

    position =
      if position_changed?(changeset, field_name) and given_position < max_position do
        given_position
      else
        max_position
      end

    old_scopes = current_collection_scope(changeset, scopes)

    Positioner.insert_at(model_name, collection_scope, field_name, position)
    Positioner.delete(model_name, old_scopes, field_name, id)

    changeset |> put_change(field_name, position)
  end

  defp update_same_scope(changeset, model_name, collection_scope, field_name) do
    id = fetch_field!(changeset, :id)

    max_position = Positioner.position_for_new(model_name, collection_scope, field_name) - 1

    current_position = Map.get(changeset.data, field_name, 1)
    given_position = get_change(changeset, field_name)

    new_position =
      if given_position < max_position do
        given_position
      else
        max_position
      end

    Positioner.update_to(
      model_name,
      collection_scope,
      field_name,
      current_position,
      new_position,
      id
    )

    changeset |> put_change(field_name, new_position)
  end

  defp collection_scope(changeset, scopes) do
    Enum.map(scopes, fn scope -> {scope, fetch_field!(changeset, scope)} end)
  end

  defp current_collection_scope(changeset, scopes) do
    Enum.map(scopes, fn scope -> {scope, Map.get(changeset.data, scope)} end)
  end

  defp scope_changed?(changeset, scopes) do
    Enum.any?(scopes, &get_change(changeset, &1))
  end

  defp position_changed?(changeset, field_name) do
    case get_change(changeset, field_name) do
      nil -> position_change_requested?(changeset, field_name)
      _ -> true
    end
  end

  # Handles an edge case where we change the scope but Ecto does not mark position
  # as changed because it occupies the same position in new scope.
  # From a row point of view it didn't change, but from a collection point of view it did.
  defp position_change_requested?(%{params: params} = _changeset, field_name)
       when is_map(params) do
    params
    |> Map.keys()
    |> Enum.any?(fn field_change -> field_change == Atom.to_string(field_name) end)
  end
end
