defmodule BotsPlatformWeb.Resolvers.Chats do
  alias BotsPlatform.{Bots, Chats, Repo}
  alias BotsPlatform.Auth.Guardian
  import Ecto.Query
  require Logger

  @default_limit 20
  @default_offset 0

  # Helper function to authenticate token
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

  # Fetch bot by ID with better error handling
  defp fetch_bot(bot_id) do
    case Repo.get(Bots.Bot, bot_id) do
      nil ->
        Logger.error("Bot not found for id: #{bot_id}")
        {:error, :not_found}
      bot ->
        {:ok, bot}
    end
  rescue
    e in Ecto.QueryError ->
      Logger.error("Database error fetching bot: #{inspect(e)}")
      {:error, :database_error}
  end

  # Authorize user for bot access
  defp authorize_user(user, bot) do
    cond do
      user.is_admin -> :ok
      bot.user_id == user.id -> :ok
      true ->
        Logger.error("User #{user.id} not authorized for bot #{bot.id}")
        {:error, :forbidden}
    end
  end

  defp fetch_chats(bot_id_str, limit, offset, search) do
      # Преобразуем строку в бинарный UUID
      case Ecto.UUID.cast(bot_id_str) do
        {:ok, uuid} ->
          limit = limit || @default_limit
          offset = offset || @default_offset

          base_query =
            from(c in Chats.Chat,
              where: c.bot_id == ^uuid,  # Используем бинарный UUID здесь
              order_by: [desc: c.updated_at],
              limit: ^limit,
              offset: ^offset
            )

          query =
            if search && search != "" do
              search_term = "%#{String.replace(search, "%", "\\%")}%"
              from(c in base_query, where: ilike(c.title, ^search_term))
            else
              base_query
            end

          try do
            {:ok, Repo.all(query)}
          rescue
            e in Ecto.QueryError ->
              Logger.error("Query error in fetch_chats: #{inspect(e)}")
              {:error, :database_error}
          end

        :error ->
          Logger.error("Invalid UUID format: #{bot_id_str}")
          {:error, :invalid_uuid}
      end
    end

    # Обновим также функцию fetch_bot
    defp fetch_bot(bot_id_str) do
      case Ecto.UUID.cast(bot_id_str) do
        {:ok, uuid} ->
          case Repo.get(Bots.Bot, uuid) do
            nil ->
              Logger.error("Bot not found for id: #{bot_id_str}")
              {:error, :not_found}
            bot ->
              {:ok, bot}
          end
        :error ->
          Logger.error("Invalid bot UUID: #{bot_id_str}")
          {:error, :invalid_uuid}
      end
    end

    # Обновим функцию authorize_user для работы с преобразованным UUID
    defp authorize_user(user, bot) do
      cond do
        user.is_admin -> :ok
        bot.user_id == user.id -> :ok
        true ->
          Logger.error("User #{user.id} not authorized for bot #{bot.id}")
          {:error, :forbidden}
      end
    end

    # Обновим функцию list_chats
    def list_chats(_, %{bot_id: bot_id, token: token} = args, _) do
      Logger.info("Listing chats with args: #{inspect(args, limit: :infinity)}")

      with {:ok, user} <- authenticate_token(token),
           {:ok, bot} <- fetch_bot(bot_id),
           :ok <- authorize_user(user, bot),
           {:ok, chats} <- fetch_chats(bot_id, args[:limit], args[:offset], args[:search]) do
        {:ok, chats}
      else
        {:error, :unauthorized} -> {:error, "Недействительный токен авторизации"}
        {:error, :not_found} -> {:error, "Бот не найден"}
        {:error, :forbidden} -> {:error, "Нет доступа"}
        {:error, :database_error} -> {:error, "Ошибка базы данных"}
        {:error, :invalid_uuid} -> {:error, "Неверный формат UUID"}
        error ->
          Logger.error("Unexpected error in list_chats: #{inspect(error)}")
          {:error, "Внутренняя ошибка сервера"}
      end
    end
end
