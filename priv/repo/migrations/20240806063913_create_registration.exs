defmodule PipeLine.Database.Repo.Migrations.CreateRegistration do
  @moduledoc false

  use Ecto.Migration

  def up do
    create table(:registration, primary_key: false) do
      add(:guild_id, :string, primary_key: true)
      add(:channel_id, :string, primary_key: true)
    end
  end

  def down do
    drop(table(:registration))
  end
end
