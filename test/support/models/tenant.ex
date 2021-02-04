defmodule Tenant do
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "tenants" do
    timestamps()
  end
end
