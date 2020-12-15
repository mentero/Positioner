defmodule Dummy do
  use Ecto.Schema

  schema "dummies" do
    field(:title, :string)
    field(:position, :integer)
    field(:idx, :integer)
    belongs_to(:tenant, Tenant)

    timestamps()
  end
end
