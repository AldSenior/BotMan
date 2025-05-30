defmodule BotsPlatform.Subscriptions.UserBot do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_bots" do
    belongs_to :user, BotsPlatform.Accounts.User
    belongs_to :bot, BotsPlatform.Bots.Bot

    timestamps()
  end

  def changeset(user_bot, attrs) do
    user_bot
    |> cast(attrs, [:user_id, :bot_id])
    |> validate_required([:user_id, :bot_id])
    |> unique_constraint([:user_id, :bot_id], name: :user_id_bot_id_unique_index)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:bot_id)
  end
end
