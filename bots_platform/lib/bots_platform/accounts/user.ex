defmodule BotsPlatform.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field(:email, :string)
    field(:name, :string)
    field(:password_hash, :string)
    field(:is_admin, :boolean, default: false)

    # Виртуальное поле для пароля
    field(:password, :string, virtual: true)

    # Отношения
    has_many(:bots, BotsPlatform.Bots.Bot)
    has_many(:user_bots, BotsPlatform.Subscriptions.UserBot)
    has_many(:subscribed_bots, through: [:user_bots, :bot])

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :password, :is_admin])
    |> validate_required([:email, :name, :password])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "должен быть действительным email")
    |> validate_length(:password, min: 6, message: "должен быть не менее 6 символов")
    |> unique_constraint(:email)
    |> put_password_hash()
  end

  defp put_password_hash(
         %Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset
       ) do
    put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
  end

  defp put_password_hash(changeset), do: changeset
end
