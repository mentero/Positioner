defmodule Positioner.MixProject do
  use Mix.Project

  def project do
    [
      app: :positioner,
      version: "0.2.0",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_sql, "~> 3.0"},
      {:postgrex, ">= 0.0.0"},
      {:ex_doc, "~> 0.23", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md": [filename: "readme", title: "README"]]
    ]
  end

  defp aliases do
    [
      test: ["ecto.create", "ecto.migrate", "test"],
      docs: ["docs", &copy_images/1]
    ]
  end

  defp copy_images(_) do
    File.mkdir("./doc/assets/")

    "./assets/*.png"
    |> Path.wildcard()
    |> Enum.each(&File.cp!(&1, "./doc/assets/#{Path.basename(&1)}"))
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
