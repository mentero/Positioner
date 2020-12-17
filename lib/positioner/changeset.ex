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
    if position_changed?(changeset, field_name) do
      given_position = get_change(changeset, field_name)
      Positioner.insert_at(model_name, collection_scope, field_name, given_position)
      changeset
    else
      new_position = Positioner.position_for_new(model_name, collection_scope, field_name)
      changeset |> put_change(field_name, new_position)
    end
  end

  defp on_update(changeset, model_name, collection_scope, scopes, field_name) do
    cond do
      scope_changed?(changeset, scopes) ->
        id = fetch_field!(changeset, :id)

        position =
          case fetch_field!(changeset, field_name) do
            nil -> Positioner.position_for_new(model_name, collection_scope, field_name)
            value -> value
          end

        old_scopes = current_collection_scope(changeset, scopes)

        Positioner.insert_at(model_name, collection_scope, field_name, position)
        Positioner.delete(model_name, old_scopes, field_name, id)

        changeset |> put_change(field_name, position)

      position_changed?(changeset, field_name) ->
        id = fetch_field!(changeset, :id)
        current_position = Map.get(changeset.data, field_name, 1)
        given_position = get_change(changeset, field_name)

        Positioner.update_to(
          model_name,
          collection_scope,
          field_name,
          current_position,
          given_position,
          id
        )

        changeset

      true ->
        changeset
    end
  end

  defp on_delete(%{data: %{id: id}} = changeset, model_name, collection_scope, field_name) do
    Positioner.delete(model_name, collection_scope, field_name, id)
    changeset
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
    not is_nil(get_change(changeset, field_name))
  end
end
