defmodule PipeLine do
  @moduledoc """
  Spawn up a base Supervisor.
  """
  use Application
  require Logger

  def start(_type, _args) do
    Logger.info("starting")
    children = [PipeLine.Impl.Core]
    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
