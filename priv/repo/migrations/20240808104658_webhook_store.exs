defmodule PipeLine.Database.Repo.Migrations.WebhookStore do
  @moduledoc false

  use Ecto.Migration

  def up do
    create table(:webhooks, primary_key: false) do
      add(:channel_id, :string, primary_key: true)
      add(:webhook_id, :string)
      add(:webhook_token, :string)
    end
  end

  def down do
    drop(table(:webhooks))
  end
end
