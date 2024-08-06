defmodule PipeLine.Database.Repo do
  use Ecto.Repo,
    otp_app: :pipe_line,
    adapter: Ecto.Adapters.SQLite3
end
