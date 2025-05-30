defmodule BotsPlatform.Chats.Chat do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "chats" do
    field :chat_id, :string
    field :title, :string
    field :type, :string
    belongs_to :bot, BotsPlatform.Bots.Bot
    timestamps(type: :utc_datetime)
  end

  def changeset(chat, attrs) do
    chat
    |> cast(attrs, [:chat_id, :title, :type, :bot_id])
    |> validate_required([:chat_id, :bot_id])
    |> unique_constraint([:chat_id, :bot_id])
    |> foreign_key_constraint(:bot_id)
  end
end
