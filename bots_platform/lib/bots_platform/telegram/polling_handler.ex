defmodule BotsPlatform.Telegram.PollingHandler do
  @moduledoc """
  Модуль для опроса обновлений от Telegram и обработки сообщений.
  """

  use GenServer
  require Logger

  alias BotsPlatform.Bots
  alias BotsPlatform.Messages
  alias Phoenix.PubSub

  @base_url "https://api.telegram.org/bot"
  @poll_interval 1000

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{bots: %{}, processed_updates: MapSet.new()},
      name: __MODULE__
    )
  end

  @impl true
  def init(state) do
    schedule_poll()
    {:ok, state}
  end

  @impl true
  def handle_info(:poll, state) do
    active_bots = Bots.list_bots() |> Enum.filter(& &1.is_active)
    Logger.info("Polling #{length(active_bots)} active bots")

    new_state = update_bots_state(active_bots, state)

    schedule_poll()
    {:noreply, new_state}
  end

  defp update_bots_state(active_bots, %{bots: bots, processed_updates: processed} = state) do
    {new_bots, new_processed} =
      Enum.reduce(active_bots, {bots, processed}, fn bot, {acc_bots, acc_processed} ->
        case verify_and_update_bot(bot, Map.get(acc_bots, bot.id), acc_processed) do
          {:ok, bot_state, updated_processed} ->
            {Map.put(acc_bots, bot.id, bot_state), updated_processed}

          :error ->
            {acc_bots, acc_processed}
        end
      end)

    %{state | bots: new_bots, processed_updates: new_processed}
  end

  defp verify_and_update_bot(bot, existing_state, processed_updates) do
    case verify_bot(bot) do
      {:ok, token} ->
        offset = get_offset(existing_state)
        {new_offset, updated_processed} = poll_updates(bot, token, offset, processed_updates)
        {:ok, %{token: token, offset: new_offset}, updated_processed}

      :error ->
        :error
    end
  end

  defp get_offset(nil), do: 0
  defp get_offset(%{offset: offset}), do: offset

  defp verify_bot(bot) do
    Logger.info("Verifying bot: #{bot.name}")
    url = "#{@base_url}#{bot.token}/getMe"

    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"ok" => true, "result" => info}} ->
            Logger.info("Bot #{bot.name} verified successfully as @#{info["username"]}")
            {:ok, bot.token}

          {:error, error} ->
            Logger.error("Failed to decode getMe response for bot #{bot.name}: #{inspect(error)}")
            :error
        end

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        Logger.error("Failed to verify bot #{bot.name}: HTTP #{code}, body: #{body}")
        :error

      {:error, error} ->
        Logger.error("Failed to verify bot #{bot.name}: #{inspect(error)}")
        :error
    end
  end

  defp poll_updates(bot, token, offset, processed_updates) do
    url = "#{@base_url}#{token}/getUpdates?offset=#{offset}&timeout=1"

    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"ok" => true, "result" => updates}} when updates != [] ->
            Logger.info("Received #{length(updates)} updates for bot #{bot.name}")
            new_processed = process_updates(updates, bot, token, processed_updates)
            new_offset = List.last(updates)["update_id"] + 1
            {new_offset, new_processed}

          {:ok, %{"ok" => true, "result" => []}} ->
            Logger.debug("No new updates for bot #{bot.name}")
            {offset, processed_updates}

          {:error, error} ->
            Logger.error(
              "Failed to decode getUpdates response for bot #{bot.name}: #{inspect(error)}"
            )

            {offset, processed_updates}
        end

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        Logger.error("Failed to get updates for bot #{bot.name}: HTTP #{code}, body: #{body}")
        {offset, processed_updates}

      {:error, error} ->
        Logger.error("Failed to get updates for bot #{bot.name}: #{inspect(error)}")
        {offset, processed_updates}
    end
  end

  defp process_updates(updates, bot, token, processed_updates) do
    Enum.reduce(updates, processed_updates, fn update, acc ->
      update_id = update["update_id"]

      if MapSet.member?(acc, update_id) do
        Logger.debug("Skipping already processed update_id: #{update_id} for bot #{bot.name}")
        acc
      else
        Task.start(fn ->
          handle_update(update, bot, token)
        end)

        MapSet.put(acc, update_id)
      end
    end)
  end

  defp handle_update(%{"message" => message} = update, bot, token) when not is_nil(message) do
    chat_id = message["chat"]["id"]
    text = message["text"] || ""
    sender = message["from"]
    sender_id = to_string(sender["id"])
    sender_name = "#{sender["first_name"]} #{sender["last_name"] || ""}"

    Logger.info("""
    Received message:
    Bot: #{bot.name}
    Text: #{text}
    From: #{sender_name} (#{sender_id})
    Chat ID: #{chat_id}
    Update ID: #{update["update_id"]}
    """)

    case Messages.create_message(%{
           chat_id: to_string(chat_id),
           sender_id: sender_id,
           sender_name: sender_name,
           text: text,
           bot_id: bot.id
         }) do
      {:ok, db_message} ->
        if String.starts_with?(text, "/") do
          handle_command(text, chat_id, bot, token)
        end

        publish_message(db_message, bot.id)

      {:error, error} ->
        Logger.error("Failed to save message for bot #{bot.name}: #{inspect(error)}")
    end
  end

  defp handle_update(update, bot, _token) do
    Logger.debug("Unhandled update type for bot #{bot.name}: #{inspect(update)}")
    :ok
  end

  defp handle_command(text, chat_id, bot, token) do
    Logger.info("Handling command '#{text}' for bot #{bot.name}")
    command_name = get_command_name(text)

    case Bots.list_bot_commands(bot.id) do
      [] ->
        Logger.info("No commands found for bot #{bot.name}")
        send_message(token, chat_id, "Команды не настроены")

      commands ->
        command = Enum.find(commands, &match_command?(&1, command_name))
        execute_command(command, chat_id, token)
    end
  end

  defp get_command_name(text) do
    case String.split(text, " ", parts: 2) do
      [cmd | _] -> cmd
      [] -> ""
    end
  end

  defp match_command?(command, command_name) do
    command.is_active && command.trigger == command_name
  end

  defp execute_command(nil, chat_id, token) do
    Logger.info("Command not found")
    send_message(token, chat_id, "Команда не найдена")
  end

  defp execute_command(command, chat_id, token) do
    Logger.info("Executing command '#{command.name}' for bot #{command.bot_id}")

    case command.response_type do
      :text ->
        send_message(token, chat_id, command.response_content)

      :image ->
        send_photo(token, chat_id, command.response_content)

      :keyboard ->
        send_keyboard(token, chat_id, command.response_content)

      unknown_type ->
        Logger.error("Unknown response type: #{unknown_type}")
        send_message(token, chat_id, "Неподдерживаемый тип команды")
    end
  end

  defp send_message(token, chat_id, text) when is_binary(text) and text != "" do
    url = "#{@base_url}#{token}/sendMessage"
    body = Jason.encode!(%{chat_id: chat_id, text: text})
    headers = [{"Content-Type", "application/json"}]

    case HTTPoison.post(url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200}} ->
        Logger.info("Message sent successfully to chat #{chat_id}")

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        Logger.error("Failed to send message to chat #{chat_id}: HTTP #{code}, body: #{body}")

      {:error, error} ->
        Logger.error("Failed to send message to chat #{chat_id}: #{inspect(error)}")
    end
  end

  defp send_message(token, chat_id, _text) do
    Logger.error("Invalid message text for chat #{chat_id}")
  end

  defp send_photo(token, chat_id, photo_url) when is_binary(photo_url) and photo_url != "" do
    url = "#{@base_url}#{token}/sendPhoto"
    body = Jason.encode!(%{chat_id: chat_id, photo: photo_url})
    headers = [{"Content-Type", "application/json"}]

    case HTTPoison.post(url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200}} ->
        Logger.info("Photo sent successfully to chat #{chat_id}")

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        Logger.error("Failed to send photo to chat #{chat_id}: HTTP #{code}, body: #{body}")

      {:error, error} ->
        Logger.error("Failed to send photo to chat #{chat_id}: #{inspect(error)}")
    end
  end

  defp send_photo(token, chat_id, _photo_url) do
    Logger.error("Invalid photo URL for chat #{chat_id}")
  end

  defp send_keyboard(token, chat_id, keyboard_json) when is_binary(keyboard_json) do
    case Jason.decode(keyboard_json) do
      {:ok, keyboard} ->
        url = "#{@base_url}#{token}/sendMessage"
        body = Jason.encode!(%{chat_id: chat_id, text: "Выберите опцию:", reply_markup: keyboard})
        headers = [{"Content-Type", "application/json"}]

        case HTTPoison.post(url, body, headers) do
          {:ok, %HTTPoison.Response{status_code: 200}} ->
            Logger.info("Keyboard sent successfully to chat #{chat_id}")

          {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
            Logger.error(
              "Failed to send keyboard to chat #{chat_id}: HTTP #{code}, body: #{body}"
            )

          {:error, error} ->
            Logger.error("Failed to send keyboard to chat #{chat_id}: #{inspect(error)}")
        end

      {:error, error} ->
        Logger.error("Failed to decode keyboard JSON for chat #{chat_id}: #{inspect(error)}")
        send_message(token, chat_id, "Ошибка при отправке клавиатуры")
    end
  end

  defp send_keyboard(token, chat_id, _keyboard_json) do
    Logger.error("Invalid keyboard JSON for chat #{chat_id}")
    send_message(token, chat_id, "Ошибка при отправке клавиатуры")
  end

  defp publish_message(message, bot_id) do
    message_data = %{
      id: message.id,
      chat_id: message.chat_id,
      sender_id: message.sender_id,
      sender_name: message.sender_name,
      text: message.text,
      bot_id: bot_id,
      inserted_at: message.inserted_at
    }

    PubSub.broadcast(BotsPlatform.PubSub, "bot:#{bot_id}", {:new_message, message_data})
  end

  defp schedule_poll do
    Process.send_after(self(), :poll, @poll_interval)
  end
end
