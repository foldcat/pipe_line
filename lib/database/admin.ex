defmodule PipeLine.Database.Admin do
  @moduledoc false

  use Ecto.Schema

  @primary_key false
  schema "admin" do
    field :user_id, :string
  end
end
