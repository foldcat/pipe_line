defmodule PipeLine.Database.Repo.Migrations.AdminTable do
  @moduledoc false

  use Ecto.Migration

  def up do
    create table(:admin, primary_key: false) do
      add(:user_id, :string, primary_key: true)
    end
  end

  def down do
    drop(table(:admin))
  end

end
