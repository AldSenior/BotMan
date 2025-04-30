defmodule BotsPlatform.Repo.Migrations.CreateCommands do
  use Ecto.Migration

  def change do
    create table(:commands, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :trigger, :string, null: false
      add :response_type, :string, null: false
      add :response_content, :text, null: false
      add :is_active, :boolean, default: true, null: false
      add :bot_id, references(:bots, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:commands, [:bot_id])
    create unique_index(:commands, [:bot_id, :trigger])
  end
end
