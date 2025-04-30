defmodule BotsPlatform.Repo.Migrations.CreateBots do
  use Ecto.Migration

  def change do
    create table(:bots, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :token, :string, null: false
      add :description, :text
      add :webhook_url, :string
      add :is_active, :boolean, default: true, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:bots, [:user_id])
    create unique_index(:bots, [:token])
  end
end
