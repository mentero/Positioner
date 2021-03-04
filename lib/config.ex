defmodule Positioner.Config do
  @moduledoc false
  @doc false
  @spec repo() :: Ecto.Repo.t()
  def repo() do
    Application.fetch_env!(:positioner, :repo)
  end
end
