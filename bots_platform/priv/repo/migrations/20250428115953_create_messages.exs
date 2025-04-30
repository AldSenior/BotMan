defmodule BotsPlatform.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :chat_id, :string, null: false
      add :sender_id, :string, null: false
      add :sender_name, :string, null: false
      add :text, :text, null: false
      add :bot_id, references(:bots, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:messages, [:bot_id])
    create index(:messages, [:inserted_at])
  end
end
