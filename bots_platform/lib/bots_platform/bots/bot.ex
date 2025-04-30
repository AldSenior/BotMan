defmodule BotsPlatform.Bots.Bot do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "bots" do
    field :name, :string
    field :token, :string
    field :description, :string
    field :webhook_url, :string
    field :is_active, :boolean, default: true

    belongs_to :user, BotsPlatform.Accounts.User
    has_many :commands, BotsPlatform.Bots.Command

    timestamps()
  end

  def changeset(bot, attrs) do
    bot
    |> cast(attrs, [:name, :token, :description, :webhook_url, :is_active, :user_id])
    |> validate_required([:name, :token, :user_id])
    |> validate_format(:token, ~r/^\d+:[A-Za-z0-9_-]{35}$/,
      message: "должен быть валидным токеном бота"
    )
    |> unique_constraint(:token)
  end
end
