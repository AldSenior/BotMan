defmodule BotsPlatform.Repo.Migrations.CreateChats do
  use Ecto.Migration

  def change do
    create table(:chats, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:chat_id, :string, null: false)
      add(:title, :string)
      add(:type, :string)
      add(:bot_id, references(:bots, type: :binary_id, on_delete: :delete_all), null: false)
      timestamps(type: :utc_datetime)
    end

    create(unique_index(:chats, [:chat_id, :bot_id], name: :chats_chat_id_bot_id_index))
  end
end
