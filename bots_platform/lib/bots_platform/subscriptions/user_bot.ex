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

# lib/bots_platform/subscriptions.ex
defmodule BotsPlatform.Subscriptions do
  import Ecto.Query
  alias BotsPlatform.Repo
  alias BotsPlatform.Subscriptions.UserBot

  def data() do
    Dataloader.Ecto.new(Repo, query: &query/2)
  end

  def query(queryable, _params) do
    queryable
  end

  @doc """
  Подписывает пользователя на бота.
  """
  def subscribe_user_to_bot(user_id, bot_id) do
    %UserBot{}
    |> UserBot.changeset(%{user_id: user_id, bot_id: bot_id})
    |> Repo.insert()
  end

  @doc """
  Отписывает пользователя от бота.
  """
  def unsubscribe_user_from_bot(user_id, bot_id) do
    UserBot
    |> where([ub], ub.user_id == ^user_id and ub.bot_id == ^bot_id)
    |> Repo.delete_all()
    |> case do
      {1, _} -> {:ok, :unsubscribed}
      {0, _} -> {:error, :not_found}
    end
  end

  @doc """
  Проверяет, подписан ли пользователь на бота.
  """
  def is_subscribed?(user_id, bot_id) do
    UserBot
    |> where([ub], ub.user_id == ^user_id and ub.bot_id == ^bot_id)
    |> Repo.exists?()
  end

  @doc """
  Получает список подписчиков бота.
  """
  def get_bot_subscribers(bot_id) do
    UserBot
    |> where([ub], ub.bot_id == ^bot_id)
    |> preload(:user)
    |> Repo.all()
    |> Enum.map(& &1.user)
  end
end
