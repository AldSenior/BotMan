defmodule BotsPlatform.Subscriptions do
  @moduledoc """
  Контекст для управления подписками пользователей на ботов.
  """

  import Ecto.Query, warn: false
  alias BotsPlatform.Repo
  alias BotsPlatform.Subscriptions.UserBot

  @doc """
  Проверяет, подписан ли пользователь на бота.
  """
  def is_subscribed?(user_id, bot_id) do
    query =
      from(ub in UserBot,
        where: ub.user_id == ^user_id and ub.bot_id == ^bot_id
      )

    Repo.exists?(query)
  end

  @doc """
  Создает подписку пользователя на бота.
  """
  def create_subscription(user_id, bot_id) do
    %UserBot{}
    |> UserBot.changeset(%{user_id: user_id, bot_id: bot_id})
    |> Repo.insert(on_conflict: :nothing)
  end

  @doc """
  Удаляет подписку пользователя на бота.
  """
  def delete_subscription(user_id, bot_id) do
    query =
      from(ub in UserBot,
        where: ub.user_id == ^user_id and ub.bot_id == ^bot_id
      )

    case Repo.delete_all(query) do
      {count, _} when count > 0 -> {:ok, nil}
      {0, _} -> {:error, :not_found}
    end
  end

  @doc """
  Получает список ID ботов, на которые подписан пользователь.
  """
  def get_user_bot_ids(user_id) do
    query =
      from(ub in UserBot,
        where: ub.user_id == ^user_id,
        select: ub.bot_id
      )

    Repo.all(query)
  end

  @doc """
  Получает список ботов, на которые подписан пользователь.
  """
  def get_user_subscribed_bots(user_id) do
    query =
      from(ub in UserBot,
        join: b in BotsPlatform.Bots.Bot,
        on: ub.bot_id == b.id,
        where: ub.user_id == ^user_id,
        select: b
      )

    Repo.all(query)
  end
end
