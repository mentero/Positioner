defmodule Positioner.TestCase do
  use ExUnit.CaseTemplate

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Positioner.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Positioner.Repo, {:shared, self()})
    end

    :ok
  end
end
