# Copyright 2024 foldcat
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule PipeLine.MixProject do
  @moduledoc false

  use Mix.Project

  def project do
    [
      app: :pipe_line,
      version: "1.0.0",
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
      {:nostrum, github: "Kraigie/nostrum"},
      {:hammer, "~> 6.1"},
      {:ecto_sqlite3, "~> 0.16"},
      {:ecto, "~> 3.10"},
      {:expletive, "~> 0.1.5"}
    ]
  end
end
