defmodule BotsPlatform.Repo.Migrations.CreateUserBots do
  use Ecto.Migration

  def change do
    create table(:user_bots, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :bot_id, references(:bots, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:user_bots, [:user_id])
    create index(:user_bots, [:bot_id])
    create unique_index(:user_bots, [:user_id, :bot_id], name: :user_id_bot_id_unique_index)
  end
end
