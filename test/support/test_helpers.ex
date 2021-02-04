defmodule Positioner.TestHelpers do
  alias Positioner.Repo

  import Ecto.Query

  @spec insert_dummy!(keyword()) :: Dummy.t()
  def insert_dummy!(attrs \\ []) do
    %Dummy{tenant: %Tenant{}} |> struct(attrs) |> Repo.insert!()
  end

  @spec insert_tenant!(keyword()) :: Tennant.t()
  def insert_tenant!(attrs \\ []) do
    %Tenant{} |> struct(attrs) |> Repo.insert!()
  end

  @spec all_dummies!() :: list(Dummy.t())
  def all_dummies!() do
    Dummy |> order_by(asc: :tenant_id, asc: :position) |> Repo.all()
  end
end
