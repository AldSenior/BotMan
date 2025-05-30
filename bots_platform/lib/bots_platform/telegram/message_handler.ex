defmodule BotsPlatform.MessageHandler do
  @moduledoc """
  Обработчик сообщений от Telegram ботов.
  Сохраняет сообщения в базу данных и обеспечивает их отображение на фронте.
  """

  alias BotsPlatform.{Messages, Chats, Bots, Repo}
  alias BotsPlatform.Messages.Message
  alias BotsPlatform.Chats.Chat
  require Logger

  @doc """
  Обрабатывает входящее сообщение от Telegram бота.
  """
  def handle_message(telegram_update, bot_token) do
    Logger.info("Handling message from bot with token: #{String.slice(bot_token, 0, 10)}...")

    with {:ok, bot} <- get_bot_by_token(bot_token),
         {:ok, message_data} <- extract_message_data(telegram_update),
         {:ok, chat} <- ensure_chat_exists(message_data, bot),
         {:ok, message} <- save_message(message_data, bot, chat) do

      Logger.info("Message saved successfully: #{message.id}")
      broadcast_message_update(message, bot)
      {:ok, message}
    else
      {:error, reason} = error ->
        Logger.error("Failed to handle message: #{inspect(reason)}")
        error
    end
  end

  # Получение бота по токену
  defp get_bot_by_token(token) do
    case Repo.get_by(Bots.Bot, token: token) do
      nil ->
        Logger.error("Bot not found for token")
        {:error, :bot_not_found}
      bot ->
        {:ok, bot}
    end
  end

  # Извлечение данных сообщения
  defp extract_message_data(%{"message" => message}), do: extract_message_fields(message)
  defp extract_message_data(%{"edited_message" => message}), do: extract_message_fields(message)
  defp extract_message_data(%{"channel_post" => message}), do: extract_message_fields(message)
  defp extract_message_data(%{"edited_channel_post" => message}), do: extract_message_fields(message)
  defp extract_message_data(_), do: {:error, :unsupported_update_type}

  defp extract_message_fields(message) do
    try do
      chat = message["chat"]
      from = message["from"] || %{}

      {:ok, %{
        chat_id: to_string(chat["id"]),
        chat_title: get_chat_title(chat, from),
        chat_type: chat["type"],
        sender_id: to_string(from["id"] || "unknown"),
        sender_name: get_sender_name(from),
        text: get_message_text(message),
        message_id: message["message_id"],
        date: message["date"]
      }}
    rescue
      e ->
        Logger.error("Failed to extract message data: #{inspect(e)}")
        {:error, :invalid_message_format}
    end
  end

  # Формирование заголовка чата
  defp get_chat_title(%{"type" => "private"} = chat, from) do
    chat["title"] || get_sender_name(from) || "Private Chat"
  end
  defp get_chat_title(chat, _), do: chat["title"] || "Group Chat"

  # Формирование имени отправителя
  defp get_sender_name(%{"username" => username}) when is_binary(username), do: "@#{username}"
  defp get_sender_name(%{"first_name" => first, "last_name" => last}), do: "#{first} #{last}"
  defp get_sender_name(%{"first_name" => first}), do: first
  defp get_sender_name(%{"last_name" => last}), do: last
  defp get_sender_name(_), do: "Unknown User"

  # Получение текста сообщения
  defp get_message_text(%{"text" => text}), do: text
  defp get_message_text(%{"caption" => caption}), do: caption
  defp get_message_text(%{"sticker" => _}), do: "[Sticker]"
  defp get_message_text(%{"photo" => _}), do: "[Photo]"
  defp get_message_text(%{"video" => _}), do: "[Video]"
  defp get_message_text(%{"audio" => _}), do: "[Audio]"
  defp get_message_text(%{"voice" => _}), do: "[Voice Message]"
  defp get_message_text(%{"document" => _}), do: "[Document]"
  defp get_message_text(%{"location" => _}), do: "[Location]"
  defp get_message_text(%{"contact" => _}), do: "[Contact]"
  defp get_message_text(%{"poll" => _}), do: "[Poll]"
  defp get_message_text(_), do: "[Unsupported Content]"

  # Создание или обновление чата
  defp ensure_chat_exists(message_data, bot) do
    case Chats.get_chat_by_chat_id(message_data.chat_id, bot.id) do
      {:ok, chat} ->
        update_chat_if_needed(chat, message_data)
      {:error, _} ->
        create_chat(message_data, bot)
    end
  end

  defp create_chat(message_data, bot) do
    Chats.create_chat(%{
      chat_id: message_data.chat_id,
      title: message_data.chat_title,
      type: message_data.chat_type,
      bot_id: bot.id
    })
  end

  defp update_chat_if_needed(chat, message_data) do
    if chat.title != message_data.chat_title or chat.type != message_data.chat_type do
      Chats.update_chat(chat, %{
        title: message_data.chat_title,
        type: message_data.chat_type
      })
    else
      {:ok, chat}
    end
  end

  # Сохранение сообщения
  defp save_message(message_data, bot, _chat) do
    Messages.create_message(%{
      chat_id: message_data.chat_id,
      sender_id: message_data.sender_id,
      sender_name: message_data.sender_name,
      text: message_data.text,
      bot_id: bot.id
    })
  end

  # Трансляция обновления
  defp broadcast_message_update(message, bot) do
    topic = "messages:#{bot.id}:#{message.chat_id}"

    Phoenix.PubSub.broadcast(
      BotsPlatform.PubSub,
      topic,
      {:new_message, message}
    )
  end
end
