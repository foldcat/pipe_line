defmodule PipeLine.Database.Repo.Migrations.BannedTable do
  @moduledoc false

  use Ecto.Migration

  def up do
    create table(:banned, primary_key: false) do
      add(:user_id, :string, primary_key: true)
    end
  end

  def down do
    drop(table(:banned))
  end

end
