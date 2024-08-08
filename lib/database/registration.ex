defmodule PipeLine.Database.Registration do
  @moduledoc false

  use Ecto.Schema

  @primary_key false
  schema "registration" do
    field :guild_id, :string
    field :channel_id, :string
  end
end
