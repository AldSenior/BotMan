defmodule BotsPlatformWeb.Resolvers.Messages do
  alias BotsPlatform.{Bots, Chats, Messages, Repo}
  alias BotsPlatform.Auth.Guardian
  import Ecto.Query
  require Logger

  @default_limit 50
  @default_offset 0

  defp authenticate_token(token) do
    clean_token = String.replace(token, ~r/^Bearer\s*/i, "")
    Logger.debug("Authenticating token: [REDACTED]")

    case Guardian.decode_and_verify(clean_token) do
      {:ok, claims} ->
        case Guardian.resource_from_claims(claims) do
          {:ok, user} ->
            Logger.debug("User authenticated successfully")
            {:ok, user}
          error ->
            Logger.error("Failed to get user from claims: #{inspect(error)}")
            {:error, :unauthorized}
        end
      error ->
        Logger.error("Token verification failed: #{inspect(error)}")
        {:error, :unauthorized}
    end
  end

  defp fetch_bot(bot_id_str) do
    case Ecto.UUID.cast(bot_id_str) do
      {:ok, uuid} ->
        case Repo.get(Bots.Bot, uuid) do
          nil ->
            Logger.error("Bot not found for id: #{bot_id_str}")
            {:error, :bot_not_found}
          bot ->
            {:ok, bot}
        end
      :error ->
        Logger.error("Invalid bot UUID: #{bot_id_str}")
        {:error, :invalid_uuid}
    end
  end

  defp authorize_user(user, bot) do
    cond do
      user.is_admin -> :ok
      bot.user_id == user.id -> :ok
      true ->
        Logger.error("User #{user.id} not authorized for bot #{bot.id}")
        {:error, :forbidden}
    end
  end

  defp fetch_messages(bot_id, chat_id, limit, offset, search) do
    limit = limit || @default_limit
    offset = offset || @default_offset

    base_query = from(m in Messages.Message,
      where: m.bot_id == ^bot_id and m.chat_id == ^chat_id,
      order_by: [asc: m.inserted_at],
      limit: ^limit,
      offset: ^offset
    )

    query = if search && search != "" do
      search_term = "%#{String.replace(search, "%", "\\%")}%"
      from(m in base_query, where: ilike(m.text, ^search_term))
    else
      base_query
    end

    try do
      {:ok, Repo.all(query)}
    rescue
      e in Ecto.QueryError ->
        Logger.error("Query error in fetch_messages: #{inspect(e)}")
        {:error, :database_error}
    end
  end

  def list_chat_messages(_, %{chat_id: chat_id, bot_id: bot_id, token: token} = args, _) do
    with {:ok, user} <- authenticate_token(token),
         {:ok, bot} <- fetch_bot(bot_id),
         :ok <- authorize_user(user, bot),
         {:ok, _chat} <- Chats.get_chat_by_chat_id(chat_id, bot.id),
         {:ok, messages} <- fetch_messages(bot.id, chat_id, args[:limit], args[:offset], args[:search]) do
      {:ok, messages}
    else
      {:error, :unauthorized} -> {:error, "Недействительный токен авторизации"}
      {:error, :invalid_uuid} -> {:error, "Неверный формат UUID"}
      {:error, :bot_not_found} -> {:error, "Бот не найден"}
      {:error, :chat_not_found} -> {:error, "Чат не найден"}
      {:error, :forbidden} -> {:error, "Нет доступа"}
      {:error, :database_error} -> {:error, "Ошибка базы данных"}
      error ->
        Logger.error("Unexpected error in list_chat_messages: #{inspect(error)}")
        {:error, "Внутренняя ошибка сервера"}
    end
  end
end
