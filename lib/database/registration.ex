defmodule PipeLine.Database.Registration do
  @moduledoc false

  use Ecto.Schema

  schema "registration" do
    field(:guild_id, :string)
    field(:channel_id, :string)
  end
end
