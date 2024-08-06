defmodule PipeLine.MixProject do
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
      {:nostrum, "~> 0.10"},
      {:ecto_sqlite3, "~> 0.16"},
      {:ecto, "~> 3.10"}
    ]
  end
end
