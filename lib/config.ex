defmodule Positioner.Config do
  def repo() do
    Application.fetch_env!(:positioner, :repo)
  end
end
