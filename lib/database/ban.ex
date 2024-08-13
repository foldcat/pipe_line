defmodule PipeLine.Database.Ban do
  @moduledoc false

  use Ecto.Schema

  @primary_key false
  schema "banned" do
    field :user_id, :string
    field :until, :utc_datetime
    field :perminant, :boolean
  end
end
