defmodule BotsPlatformWeb.Resolvers.Bots do
  alias BotsPlatform.Bots
  alias BotsPlatform.Auth.Guardian
  require Logger

  # Вспомогательная функция для проверки токена
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

  # Список ботов
  def list_bots(_, %{token: token}, _) do
    Logger.info("Listing bots for token: #{token}")

    case authenticate_token(token) do
      {:ok, user} ->
        bots =
          if user.is_admin do
            Logger.info("Listing all bots for admin")
            Bots.list_bots()
          else
            Logger.info("Listing bots for user #{user.id}")
            Bots.list_user_bots(user.id)
          end

        {:ok, bots}

      error ->
        Logger.error("Authentication failed: #{inspect(error)}")
        error
    end
  end

  # Получение бота
  def get_bot(_, %{id: id, token: token}, _) when is_binary(token) do
    with {:ok, user} <- authenticate_token(token),
         bot when not is_nil(bot) <- Bots.get_bot(id) do
      cond do
        user.is_admin || bot.user_id == user.id -> {:ok, bot}
        true -> {:error, "Нет доступа к этому боту"}
      end
    else
      nil -> {:error, "Бот не найден"}
      error -> error
    end
  end

  # Создание бота
  def create_bot(_, args, _) do
    Logger.info("Create bot called with args: #{inspect(args, pretty: true)}")

    case args do
      %{input: params, token: token} ->
        clean_token = String.replace(token, "Bearer ", "")
        Logger.info("Processing with token: #{clean_token}")

        with {:ok, claims} <- Guardian.decode_and_verify(clean_token) do
          Logger.info("Token verified, claims: #{inspect(claims)}")

          case Guardian.resource_from_claims(claims) do
            {:ok, user} ->
              Logger.info("User found: #{inspect(user)}")
              bot_params = Map.put(params, :user_id, user.id)

              case Bots.create_bot(bot_params) do
                {:ok, bot} ->
                  Logger.info("Bot created successfully: #{inspect(bot)}")
                  {:ok, bot}

                {:error, changeset} ->
                  Logger.error("Bot creation failed: #{inspect(changeset.errors)}")
                  {:error, format_changeset_errors(changeset)}
              end

            {:error, reason} ->
              Logger.error("Failed to get user from claims: #{inspect(reason)}")
              {:error, "Failed to authenticate user"}
          end
        else
          {:error, reason} ->
            Logger.error("Token verification failed: #{inspect(reason)}")
            {:error, "Invalid token"}

          error ->
            Logger.error("Unexpected error: #{inspect(error)}")
            {:error, "Unexpected error occurred"}
        end

      _ ->
        Logger.error("Invalid arguments provided")
        {:error, "Invalid arguments"}
    end
  end

  # Обновление бота
  def update_bot(_, %{id: id, input: params, token: token}, _) when is_binary(token) do
    with {:ok, user} <- authenticate_token(token),
         bot when not is_nil(bot) <- Bots.get_bot(id) do
      cond do
        user.is_admin || bot.user_id == user.id -> Bots.update_bot(bot, params)
        true -> {:error, "Нет доступа к этому боту"}
      end
    else
      nil -> {:error, "Бот не найден"}
      error -> error
    end
  end

  # Удаление бота
  def delete_bot(_, %{id: id, token: token}, _) when is_binary(token) do
    with {:ok, user} <- authenticate_token(token),
         bot when not is_nil(bot) <- Bots.get_bot(id) do
      cond do
        user.is_admin || bot.user_id == user.id ->
          case Bots.delete_bot(bot) do
            {:ok, _bot} ->
              {:ok, %{id: id, success: true, message: "Bot deleted successfully"}}

            {:error, changeset} ->
              Logger.error("Bot deletion failed: #{inspect(changeset.errors)}")
              {:error, format_changeset_errors(changeset)}
          end

        true ->
          {:error, "Нет доступа к этому боту"}
      end
    else
      nil -> {:error, "Бот не найден"}
      error -> error
    end
  end

  # Список команд бота
  def list_commands(_, %{bot_id: bot_id, token: token}, _) when is_binary(token) do
    with {:ok, user} <- authenticate_token(token),
         bot when not is_nil(bot) <- Bots.get_bot(bot_id) do
      cond do
        user.is_admin || bot.user_id == user.id -> {:ok, Bots.list_bot_commands(bot_id)}
        true -> {:error, "Нет доступа к этому боту"}
      end
    else
      nil -> {:error, "Бот не найден"}
      error -> error
    end
  end

  # Создание команды
  def create_command(_, args, _) do
    Logger.info("Create command called with args: #{inspect(args, pretty: true)}")

    case args do
      %{input: params, token: token} ->
        clean_token = String.replace(token, "Bearer ", "")
        Logger.info("Processing with token: #{clean_token}")

        with {:ok, claims} <- Guardian.decode_and_verify(clean_token) do
          Logger.info("Token verified, claims: #{inspect(claims)}")

          case Guardian.resource_from_claims(claims) do
            {:ok, user} ->
              Logger.info("User found: #{inspect(user)}")

              case Bots.get_bot(params.bot_id) do
                nil ->
                  {:error, "Бот не найден"}

                bot ->
                  if user.is_admin || bot.user_id == user.id do
                    case Bots.create_command(params) do
                      {:ok, command} ->
                        Logger.info("Command created successfully: #{inspect(command)}")
                        {:ok, command}

                      {:error, changeset} ->
                        Logger.error("Command creation failed: #{inspect(changeset.errors)}")
                        {:error, format_changeset_errors(changeset)}
                    end
                  else
                    {:error, "Нет доступа к этому боту"}
                  end
              end

            {:error, reason} ->
              Logger.error("Failed to get user from claims: #{inspect(reason)}")
              {:error, "Failed to authenticate user"}
          end
        else
          {:error, reason} ->
            Logger.error("Token verification failed: #{inspect(reason)}")
            {:error, "Invalid token"}

          error ->
            Logger.error("Unexpected error: #{inspect(error)}")
            {:error, "Unexpected error occurred"}
        end

      _ ->
        Logger.error("Invalid arguments provided")
        {:error, "Invalid arguments"}
    end
  end

  # Обновление команды
  def update_command(_, %{id: id, input: params, token: token}, _) when is_binary(token) do
    with {:ok, user} <- authenticate_token(token),
         command when not is_nil(command) <- Bots.get_command(id),
         bot when not is_nil(bot) <- Bots.get_bot(command.bot_id) do
      cond do
        user.is_admin || bot.user_id == user.id -> Bots.update_command(command, params)
        true -> {:error, "Нет доступа к этой команде"}
      end
    else
      nil -> {:error, "Команда или бот не найдены"}
      error -> error
    end
  end

  # Удаление команды
  def delete_command(_, %{id: id, token: token}, _) when is_binary(token) do
    with {:ok, user} <- authenticate_token(token),
         command when not is_nil(command) <- Bots.get_command(id),
         bot when not is_nil(bot) <- Bots.get_bot(command.bot_id) do
      cond do
        user.is_admin || bot.user_id == user.id -> Bots.delete_command(command)
        true -> {:error, "Нет доступа к этой команде"}
      end
    else
      nil -> {:error, "Команда или бот не найдены"}
      error -> error
    end
  end

  # Форматирование ошибок changeset
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

  # Безопасное преобразование в строку
  defp safe_to_string(value) when is_atom(value), do: Atom.to_string(value)
  defp safe_to_string(value) when is_binary(value), do: value
  defp safe_to_string(value) when is_number(value), do: to_string(value)
  defp safe_to_string(_value), do: "invalid value"

  # Удаляем дублирующую функцию format_errors
  # defp format_errors(changeset), do: format_changeset_errors(changeset)
end
