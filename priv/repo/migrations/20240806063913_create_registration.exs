defmodule PipeLine.Database.Repo.Migrations.CreateRegistration do
  use Ecto.Migration

  def change do
    create table(:registration) do
      add :guild_id, :string, null: false
      add :channel_id, :string, null: false
    end

  end
end
