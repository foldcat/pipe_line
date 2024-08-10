defmodule PipeLine.Database.Webhooks do
  @moduledoc false

  use Ecto.Schema

  @primary_key false
  schema "webhooks" do
    field :channel_id, :string
    field :webhook_id, :string
    field :webhook_token, :string
  end
end
