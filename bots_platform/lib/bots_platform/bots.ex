defmodule BotsPlatform.Bots do
  import Ecto.Query
  alias BotsPlatform.Repo
  alias BotsPlatform.Bots.{Bot, Command}
  require Logger
  alias HTTPoison

  def data() do
    Dataloader.Ecto.new(Repo, query: &query/2)
  end

  def query(queryable, _params) do
    queryable
  end

  @doc """
  Создает нового бота.
  """
  def create_bot(attrs \\ %{}) do
    %Bot{}
    |> Bot.changeset(attrs)
    |> Repo.insert()
  end


  @doc """
  Получает бота по ID.
  """
  def get_bot(id) do
    Repo.get(Bot, id)
    |> Repo.preload([:user, :commands])
  end

  @doc """
  Получает список всех ботов.
  """
  def list_bots do
    Logger.info("Fetching all bots")

    Bot
    |> Repo.all()
    |> Repo.preload([:user, :commands])
  end

  @doc """
  Получает список ботов пользователя.
  """
  def list_user_bots(user_id) do
    Logger.info("Fetching bots for user #{user_id}")

    Bot
    |> where([b], b.user_id == ^user_id)
    |> Repo.all()
    |> Repo.preload([:user, :commands])
  end

  @doc """
  Обновляет бота.
  """
  def update_bot(%Bot{} = bot, attrs) do
    bot
    |> Bot.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Удаляет бота.
  """
  def delete_bot(%Bot{} = bot) do
    Repo.delete(bot)
  end

  @doc """
  Получает список команд бота.
  """
  def list_bot_commands(bot_id) do
    Command
    |> where(bot_id: ^bot_id)
    |> where(is_active: true)
    |> Repo.all()
  end

  @doc """
  Создает новую команду для бота.
  """
  def create_command(attrs \\ %{}) do
    Logger.debug("Creating command with attrs: #{inspect(attrs)}")

    %Command{}
    |> Command.changeset(attrs)
    |> validate_response_type()
    |> Repo.insert()
  end

  @doc """
  Обновляет команду.
  """
  def update_command(%Command{} = command, attrs) do
    command
    |> Command.changeset(attrs)
    |> validate_response_type()
    |> Repo.update()
  end

  @doc """
  Удаляет команду.
  """
  def delete_command(%Command{} = command) do
    Repo.delete(command)
  end

  @doc """
  Получает команду по ID.
  """
  def get_command(id) do
    Repo.get(Command, id)
    |> Repo.preload(:bot)
  end

  @doc """
  Проверяет статус webhook для бота.
  """
  def check_webhook_status(%Bot{} = bot) do
    Logger.info("Checking webhook status for bot #{bot.name}")
    url = "https://api.telegram.org/bot#{bot.token}/getWebhookInfo"

    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"ok" => true, "result" => webhook_info}} ->
            status =
              cond do
                webhook_info["url"] == "" ->
                  "inactive"

                webhook_info["has_custom_certificate"] ||
                    webhook_info["pending_update_count"] == 0 ->
                  "active"

                true ->
                  "error"
              end

            bot = bot |> Ecto.Changeset.change(%{webhook_status: status}) |> Repo.update!()
            {:ok, bot}

          {:error, error} ->
            Logger.error("Failed to decode webhook info for bot #{bot.name}: #{inspect(error)}")
            {:error, "Ошибка обработки ответа Telegram API"}
        end

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        Logger.error("Failed to check webhook for bot #{bot.name}: HTTP #{code}, body: #{body}")
        {:error, "Ошибка запроса к Telegram API"}

      {:error, error} ->
        Logger.error("Failed to check webhook for bot #{bot.name}: #{inspect(error)}")
        {:error, "Сетевая ошибка"}
    end
  end

  @doc """
  Отправляет сообщение от имени бота в чат.
  """
  def send_message(bot_id, chat_id, text) do
      case Ecto.UUID.cast(bot_id) do
        {:ok, uuid} ->
          bot = get_bot(uuid)

          if bot do
            url = "https://api.telegram.org/bot#{bot.token}/sendMessage"

            payload =
              Jason.encode!(%{
                "chat_id" => chat_id,
                "text" => text
              })

            case HTTPoison.post(url, payload, [{"Content-Type", "application/json"}]) do
              {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
                case Jason.decode(body) do
                  {:ok, %{"ok" => true}} ->
                    {:ok, "Message sent"}

                  {:ok, %{"ok" => false, "description" => error}} ->
                    {:error, error}

                  {:error, _} ->
                    {:error, "Failed to decode response"}
                end

              {:error, %HTTPoison.Error{reason: reason}} ->
                {:error, reason}
            end
          else
            {:error, "Bot not found"}
          end

        :error ->
          {:error, "Invalid bot ID format"}
      end
    end

  defp validate_response_type(changeset) do
    response_type = Ecto.Changeset.get_field(changeset, :response_type)

    case response_type do
      type
      when type in [:text, :image, :document, :video, :sticker, :animation, :voice, :keyboard] ->
        changeset

      _ ->
        Ecto.Changeset.add_error(changeset, :response_type, "Недопустимый тип ответа")
    end
  end
end
