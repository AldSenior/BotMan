defmodule BotsPlatform.Chats.Chat do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "chats" do
    field :chat_id, :string
    field :title, :string
    field :type, :string

    belongs_to :bot, BotsPlatform.Bots.Bot, type: :binary_id
    has_many :messages, BotsPlatform.Messages.Message

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(chat, attrs) do
    chat
    |> cast(attrs, [:chat_id, :title, :type, :bot_id])
    |> validate_required([:chat_id, :bot_id])
    |> unique_constraint(:chat_id, name: :chats_chat_id_bot_id_index)
  end
end
