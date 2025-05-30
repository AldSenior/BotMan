defmodule BotsPlatformWeb.Resolvers.Messages do
  alias BotsPlatform.{Messages, Bots, Repo}
  alias BotsPlatform.Auth.Guardian
  import Ecto.Query, warn: false
  require Logger

  # List all messages for a bot (used in the `messages` query)
  def list_messages(_, %{bot_id: bot_id, token: token}, _) do
    with {:ok, user} <- authenticate_token(token),
         {:ok, bot} <- fetch_bot(bot_id),
         :ok <- authorize_user(user, bot) do
      try do
        messages =
          Messages.Message
          |> where(bot_id: ^bot_id)
          |> order_by([m], desc: m.inserted_at)
          |> Repo.all()
        {:ok, messages}
      rescue
        e in Ecto.QueryError ->
          Logger.error("Query error in list_messages: #{inspect(e)}")
          {:error, "Ошибка запроса"}
      end
    else
      {:error, :unauthorized} ->
        {:error, "Недействительный токен авторизации"}
      error ->
        Logger.error("Failed to fetch messages: #{inspect(error)}")
        error
    end
  end

  # List messages for a specific chat with pagination and search
  def list_chat_messages(_, %{chat_id: chat_id, bot_id: bot_id, token: token, limit: limit, offset: offset, search: search}, _) do
    with {:ok, user} <- authenticate_token(token),
         {:ok, bot} <- fetch_bot(bot_id),
         :ok <- authorize_user(user, bot),
         {:ok, messages} <- fetch_chat_messages(chat_id, bot_id, limit, offset, search) do
      {:ok, messages}
    else
      {:error, :unauthorized} ->
        {:error, "Недействительный токен авторизации"}
      error ->
        Logger.error("Failed to fetch chat messages: #{inspect(error)}")
        error
    end
  end

  def list_chat_messages(_, %{chat_id: chat_id, bot_id: bot_id, token: token, limit: limit, offset: offset}, _) do
    list_chat_messages(nil, %{chat_id: chat_id, bot_id: bot_id, token: token, limit: limit, offset: offset, search: nil}, nil)
  end

  # Create a new message
  def create_message(_, %{input: input, token: token}, _) do
    clean_token = String.replace(token, "Bearer ", "")
    Logger.debug("Creating message with token: #{clean_token}")

    with {:ok, user} <- authenticate_token(token),
         {:ok, bot} <- fetch_bot(input.bot_id),
         :ok <- authorize_user(user, bot) do
      message_params = Map.merge(input, %{sender_id: bot.telegram_user_id, sender_name: bot.name})

      case Messages.create_message(message_params) do
        {:ok, message} ->
          Logger.info("Message created successfully: #{inspect(message)}")
          {:ok, message}
        {:error, changeset} ->
          Logger.error("Message creation failed: #{inspect(changeset.errors)}")
          {:error, format_changeset_errors(changeset)}
      end
    else
      {:error, :unauthorized} ->
        {:error, "Недействительный токен авторизации"}
      error ->
        Logger.error("Failed to create message: #{inspect(error)}")
        error
    end
  end

  # Fetch messages for a specific chat with pagination and search
  defp fetch_chat_messages(chat_id, bot_id, limit, offset, search) do
    base_query =
      from m in Messages.Message,
        where: m.chat_id == ^chat_id and m.bot_id == ^bot_id,
        limit: ^limit,
        offset: ^offset,
        order_by: [desc: m.inserted_at]

    query =
      if search do
        search_term = "%#{search}%"
        from m in base_query, where: ilike(m.text, ^search_term)
      else
        base_query
      end

    try do
      messages = Repo.all(query)
      {:ok, messages}
    rescue
      e in Ecto.QueryError ->
        Logger.error("Query error in fetch_chat_messages: #{inspect(e)}")
        {:error, "Ошибка запроса"}
    end
  end

  # Fetch bot by ID
  defp fetch_bot(bot_id) do
    case Repo.get(Bots.Bot, bot_id) do
      nil -> {:error, "Бот не найден"}
      bot -> {:ok, bot}
    end
  end

  # Authorize user for bot access
  defp authorize_user(user, bot) do
    if user.is_admin || bot.user_id == user.id do
      :ok
    else
      {:error, "Нет доступа"}
    end
  end

  # Authenticate token
  defp authenticate_token(token) when is_binary(token) do
    clean_token = String.replace(token, "Bearer ", "")
    Logger.debug("Authenticating token: #{clean_token}")

    case Guardian.decode_and_verify(clean_token) do
      {:ok, claims} ->
        case Guardian.resource_from_claims(claims) do
          {:ok, user} ->
            Logger.debug("User authenticated: #{inspect(user)}")
            {:ok, user}
          {:error, reason} ->
            Logger.error("Failed to get user from claims: #{inspect(reason)}")
            {:error, "Invalid token"}
        end
      {:error, reason} ->
        Logger.error("Token verification failed: #{inspect(reason)}")
        {:error, "Invalid token"}
    end
  end

  # Format changeset errors
  defp format_changeset_errors(changeset) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Enum.reduce(opts, msg, fn {key, value}, acc ->
          safe_value = safe_to_string(value)
          String.replace(acc, "%{#{key}}", safe_value)
        end)
      end)
      |> Enum.map(fn {field, errors} ->
        "#{field}: #{Enum.join(errors, ", ")}"
      end)
      |> Enum.join("; ")

    %{message: "Validation failed", details: errors}
  end

  def list_chat_messages(_, args, _) do
    %{
      bot_id: bot_id,
      chat_id: chat_id,
      token: token,
      limit: limit,
      offset: offset
    } = args

    with {:ok, user} <- authenticate_token(token),
         {:ok, bot} <- fetch_bot(bot_id),
         :ok <- authorize_user(user, bot) do
      query = from(m in Message,
               where: m.bot_id == ^bot_id and m.chat_id == ^chat_id,
               order_by: [desc: m.inserted_at],
               limit: ^limit,
               offset: ^offset
             )

      {:ok, Repo.all(query)}
    end
  end
  # Safe conversion to string
  defp safe_to_string(value) when is_atom(value), do: Atom.to_string(value)
  defp safe_to_string(value) when is_binary(value), do: value
  defp safe_to_string(value) when is_number(value), do: to_string(value)
  defp safe_to_string(_value), do: "invalid value"
end
