ExUnit.start()

Positioner.Repo.start_link()

Ecto.Adapters.SQL.Sandbox.mode(Positioner.Repo, :manual)
