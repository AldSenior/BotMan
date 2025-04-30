defmodule BotsPlatform.Messages.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "messages" do
    field :chat_id, :string
    field :sender_id, :string
    field :sender_name, :string
    field :text, :string

    belongs_to :bot, BotsPlatform.Bots.Bot

    timestamps()
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:chat_id, :sender_id, :sender_name, :text, :bot_id])
    |> validate_required([:chat_id, :sender_id, :sender_name, :text, :bot_id])
    |> foreign_key_constraint(:bot_id)
  end
end
