defmodule Positioner.Changeset do
  import Ecto.Changeset

  def set_order(changeset, scopes \\ [], field_name \\ :position) do
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
      new_position = Positioner.position_for_new(model_name, collection_scope)
      changeset |> put_change(field_name, new_position)
    end
  end

  def on_update(changeset, model_name, collection_scope, scopes, field_name) do
    cond do
      scope_changed?(changeset, scopes) ->
        id = fetch_field!(changeset, :id)
        position = fetch_field!(changeset, field_name)
        old_scopes = current_collection_scope(changeset, scopes)

        Positioner.insert_at(model_name, collection_scope, field_name, position)
        Positioner.delete(model_name, old_scopes, field_name, id)

      position_changed?(changeset, field_name) ->
        id = fetch_field!(changeset, :id)
        given_position = get_change(changeset, field_name)
        Positioner.update_to(model_name, collection_scope, field_name, given_position, id)

      true ->
        nil
    end

    changeset
  end

  def on_delete(%{data: %{id: id}} = changeset, model_name, collection_scope, field_name) do
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
