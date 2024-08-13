defmodule PipeLine.MixProject do
  @moduledoc false

  use Mix.Project

  def project do
    [
      app: :pipe_line,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {PipeLine, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      # {:nostrum, "~> 0.10"},
      {:nostrum, github: "foldcat/nostrum"},
      {:hammer, "~> 6.1"},
      {:ecto_sqlite3, "~> 0.16"},
      {:ecto, "~> 3.10"},
      {:expletive, "~> 0.1.5"}
    ]
  end
end
