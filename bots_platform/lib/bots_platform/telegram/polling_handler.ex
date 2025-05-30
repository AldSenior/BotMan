# lib/bots_platform/telegram/polling_handler.ex
defmodule BotsPlatform.Telegram.PollingHandler do
  @moduledoc """
  Модуль для опроса обновлений от Telegram и обработки сообщений.
  """

  use GenServer
  require Logger

  alias BotsPlatform.{Bots, Messages, Chats}
  alias Phoenix.PubSub

  @base_url "https://api.telegram.org/bot"
  @poll_interval 1000
  @request_timeout 10_000
  @max_attempts 3
  @retry_delay 1_000

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
    options = [timeout: @request_timeout, recv_timeout: @request_timeout]

    case http_request(:get, url, [], options, 1) do
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
    options = [timeout: @request_timeout, recv_timeout: @request_timeout]

    case http_request(:get, url, [], options, 1) do
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
    Logger.debug("Handling message update for bot #{bot.name}: #{inspect(update, limit: 10)}")
    chat_id = message["chat"]["id"]
    sender = message["from"]
    sender_id = to_string(sender["id"])
    sender_name = "#{sender["first_name"]} #{sender["last_name"] || ""}"
    chat_type = message["chat"]["type"]
    chat_title = message["chat"]["title"] || "#{sender_name}'s Chat"

    Logger.debug("Attempting to ensure chat for chat_id: #{chat_id}, bot_id: #{bot.id}")

    # Создаем или получаем чат
    case ensure_chat(to_string(chat_id), bot.id, chat_title, chat_type) do
      {:ok, chat} ->
        # Публикуем информацию о чате только если он успешно создан/найден
        publish_chat(chat, bot.id)

        cond do
          Map.has_key?(message, "text") ->
            text = message["text"]

            Logger.info("""
            Received message:
            Bot: #{bot.name}
            Text: #{text}
            From: #{sender_name} (#{sender_id})
            Chat ID: #{chat_id}
            Update ID: #{update["update_id"]}
            """)

            case find_button_action(text, bot.id) do
              {:ok, command, action} ->
                Logger.debug("Found action for button text: #{text}, action: #{inspect(action)}")
                execute_action(action, token, chat_id)

                save_message(
                  %{
                    chat_id: to_string(chat_id),
                    sender_id: sender_id,
                    sender_name: sender_name,
                    text: text,
                    bot_id: bot.id
                  },
                  bot.id
                )

              nil ->
                save_and_handle_message(
                  %{
                    chat_id: to_string(chat_id),
                    sender_id: sender_id,
                    sender_name: sender_name,
                    text: text,
                    bot_id: bot.id
                  },
                  bot,
                  token,
                  chat_id,
                  text
                )
            end

          Map.has_key?(message, "sticker") ->
            sticker = message["sticker"]
            file_id = sticker["file_id"]

            Logger.info("""
            Received sticker:
            Bot: #{bot.name}
            File ID: #{file_id}
            From: #{sender_name} (#{sender_id})
            Chat ID: #{chat_id}
            Update ID: #{update["update_id"]}
            """)

            save_message(
              %{
                chat_id: to_string(chat_id),
                sender_id: sender_id,
                sender_name: sender_name,
                text: "Sticker: #{file_id}",
                bot_id: bot.id
              },
              bot.id
            )

            send_sticker(token, chat_id, file_id)
            send_message(token, chat_id, "Получен стикер с ID: #{file_id}")

          Map.has_key?(message, "contact") ->
            contact = message["contact"]

            Logger.info("""
            Received contact:
            Bot: #{bot.name}
            Phone: #{contact["phone_number"]}
            From: #{sender_name} (#{sender_id})
            Chat ID: #{chat_id}
            Update ID: #{update["update_id"]}
            """)

            save_and_handle_message(
              %{
                chat_id: to_string(chat_id),
                sender_id: sender_id,
                sender_name: sender_name,
                text: "Contact: #{contact["phone_number"]}",
                bot_id: bot.id
              },
              bot,
              token,
              chat_id,
              nil
            )

            send_message(token, chat_id, "Спасибо за отправку контакта!")

          Map.has_key?(message, "location") ->
            location = message["location"]

            Logger.info("""
            Received location:
            Bot: #{bot.name}
            Latitude: #{location["latitude"]}
            Longitude: #{location["longitude"]}
            From: #{sender_name} (#{sender_id})
            Chat ID: #{chat_id}
            Update ID: #{update["update_id"]}
            """)

            save_and_handle_message(
              %{
                chat_id: to_string(chat_id),
                sender_id: sender_id,
                sender_name: sender_name,
                text: "Location: #{location["latitude"]}, #{location["longitude"]}",
                bot_id: bot.id
              },
              bot,
              token,
              chat_id,
              nil
            )

            send_message(token, chat_id, "Спасибо за отправку местоположения!")

          true ->
            Logger.debug("Unhandled message type for bot #{bot.name}: #{inspect(message)}")
            send_message(token, chat_id, "Тип сообщения не поддерживается")
        end

      {:error, error} ->
        Logger.error(
          "Failed to ensure chat for bot #{bot.name}, chat_id #{chat_id}: #{inspect(error)}"
        )
    end
  rescue
    e ->
      Logger.error("Unexpected error in handle_update for bot #{bot.name}: #{inspect(e)}")
      Logger.error(Exception.format_stacktrace())
  end

  defp handle_update(%{"callback_query" => callback_query} = update, bot, token) do
    chat_id = callback_query["message"]["chat"]["id"]
    callback_data = callback_query["data"]
    Logger.info("Received callback_query for bot #{bot.name}: #{callback_data}")
    command = find_command_by_callback(bot.id, callback_data)

    case command do
      nil ->
        send_message(token, chat_id, "Действие не найдено.")
        answer_callback_query(token, callback_query["id"])

      command ->
        case Jason.decode(command.response_content) do
          {:ok, %{"actions" => actions}} ->
            case Map.get(actions, callback_data) do
              nil ->
                send_message(token, chat_id, "Действие не определено.")

              action ->
                execute_action(action, token, chat_id)
            end

            answer_callback_query(token, callback_query["id"])

          {:error, error} ->
            Logger.error("Failed to decode response_content: #{inspect(error)}")
            send_message(token, chat_id, "Ошибка обработки действия.")
            answer_callback_query(token, callback_query["id"])
        end
    end

    :ok
  end

  defp handle_update(update, bot, _token) do
    Logger.debug("Unhandled update type for bot #{bot.name}: #{inspect(update)}")
    :ok
  end

  defp ensure_chat(chat_id, bot_id, title, type) do
    Logger.debug("Ensuring chat: chat_id=#{chat_id}, bot_id=#{bot_id}, title=#{title}, type=#{type}")

    case Chats.get_chat_by_chat_id(chat_id, bot_id) do
      nil ->
        Logger.info("Creating new chat for chat_id: #{chat_id}, bot_id: #{bot_id}")
        chat_attrs = %{
          chat_id: chat_id,
          bot_id: bot_id,
          title: title,
          type: type
        }

        case Chats.create_chat(chat_attrs) do
          {:ok, chat} ->
            Logger.info("Chat created successfully: #{chat_id}")
            {:ok, chat}
          {:error, changeset} ->
            Logger.error("Failed to create chat: #{inspect(changeset.errors)}")
            {:error, changeset}
        end
      chat ->
        Logger.debug("Chat already exists for chat_id: #{chat_id}, bot_id: #{bot_id}")
        {:ok, chat}
    end
  end

  defp publish_chat(%{id: id, chat_id: chat_id, title: title, type: type, inserted_at: inserted_at} = _chat, bot_id) do
    chat_data = %{
      id: id,
      chat_id: chat_id,
      title: title,
      type: type,
      bot_id: bot_id,
      inserted_at: inserted_at
    }

    Logger.debug("Broadcasting new_chat for bot_id: #{bot_id}, chat: #{inspect(chat_data)}")
    PubSub.broadcast(BotsPlatform.PubSub, "bot:#{bot_id}", {:new_chat, chat_data})
  end

  defp publish_chat(other, _bot_id) do
    Logger.error("publish_chat received invalid chat data: #{inspect(other)}")
  end


  defp find_button_action(received_text, bot_id) do
    commands = Bots.list_bot_commands(bot_id)

    Enum.find_value(commands, fn command ->
      case Jason.decode(command.response_content) do
        {:ok, %{"keyboard" => keyboard, "actions" => actions}} ->
          Enum.find_value(keyboard, fn row ->
            Enum.find_value(row, fn btn ->
              if Map.get(btn, "text") == received_text && Map.has_key?(btn, "send_text") &&
                   Map.has_key?(actions, btn["send_text"]) do
                Logger.debug(
                  "Found button with text: #{received_text}, send_text: #{btn["send_text"]}"
                )

                {:ok, command, actions[btn["send_text"]]}
              end
            end)
          end)

        _ ->
          nil
      end
    end)
  end

  defp save_and_handle_message(message_attrs, bot, token, chat_id, processed_text) do
    Logger.debug("Saving and handling message: #{inspect(message_attrs)}")

    case Messages.create_message(message_attrs) do
      {:ok, db_message} ->
        Logger.info("Message saved successfully for chat_id: #{message_attrs.chat_id}")
        handle_command(processed_text || message_attrs.text, chat_id, bot, token)
        publish_message(db_message, bot.id)

      {:error, error} ->
        Logger.error("Failed to save message for bot #{bot.name}: #{inspect(error)}")
    end
  end

  defp save_message(message_attrs, bot_id) do
    Logger.debug("Saving message: #{inspect(message_attrs)}")

    case Messages.create_message(message_attrs) do
      {:ok, db_message} ->
        Logger.info("Message saved successfully for chat_id: #{message_attrs.chat_id}")
        publish_message(db_message, bot_id)

      {:error, error} ->
        Logger.error("Failed to save message for bot #{bot_id}: #{inspect(error)}")
    end
  end

  defp find_command_by_callback(bot_id, callback_data) do
    commands = Bots.list_bot_commands(bot_id)

    Enum.find(commands, fn command ->
      case Jason.decode(command.response_content) do
        {:ok, %{"actions" => actions}} ->
          Map.has_key?(actions, callback_data)

        _ ->
          false
      end
    end)
  end

  defp execute_action(%{"type" => "send_message", "content" => content}, token, chat_id) do
    send_message(token, chat_id, content)
  end

  defp execute_action(%{"type" => "send_photo", "content" => content}, token, chat_id) do
    send_photo(token, chat_id, content)
  end

  defp execute_action(%{"type" => "send_document", "content" => content}, token, chat_id) do
    send_document(token, chat_id, content)
  end

  defp execute_action(%{"type" => "send_video", "content" => content}, token, chat_id) do
    send_video(token, chat_id, content)
  end

  defp execute_action(%{"type" => "send_sticker", "content" => content}, token, chat_id) do
    send_sticker(token, chat_id, content)
  end

  defp execute_action(%{"type" => "send_animation", "content" => content}, token, chat_id) do
    send_animation(token, chat_id, content)
  end

  defp execute_action(%{"type" => "send_voice", "content" => content}, token, chat_id) do
    send_voice(token, chat_id, content)
  end

  defp execute_action(action, token, chat_id) do
    Logger.error("Unknown action type: #{inspect(action)}")
    send_message(token, chat_id, "Неподдерживаемое действие.")
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

      :document ->
        send_document(token, chat_id, command.response_content)

      :video ->
        send_video(token, chat_id, command.response_content)

      :sticker ->
        send_sticker(token, chat_id, command.response_content)

      :animation ->
        send_animation(token, chat_id, command.response_content)

      :voice ->
        send_voice(token, chat_id, command.response_content)

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
    options = [timeout: @request_timeout, recv_timeout: @request_timeout]

    case http_request(:post, url, body, headers, options, 1) do
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
    options = [timeout: @request_timeout, recv_timeout: @request_timeout]

    case http_request(:post, url, body, headers, options, 1) do
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

  defp send_document(token, chat_id, document_url)
       when is_binary(document_url) and document_url != "" do
    url = "#{@base_url}#{token}/sendDocument"
    body = Jason.encode!(%{chat_id: chat_id, document: document_url})
    headers = [{"Content-Type", "application/json"}]
    options = [timeout: @request_timeout, recv_timeout: @request_timeout]

    case http_request(:post, url, body, headers, options, 1) do
      {:ok, %HTTPoison.Response{status_code: 200}} ->
        Logger.info("Document sent successfully to chat #{chat_id}")

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        Logger.error("Failed to send document to chat #{chat_id}: HTTP #{code}, body: #{body}")

      {:error, error} ->
        Logger.error("Failed to send document to chat #{chat_id}: #{inspect(error)}")
    end
  end

  defp send_document(token, chat_id, _document_url) do
    Logger.error("Invalid document URL for chat #{chat_id}")
    send_message(token, chat_id, "Ошибка при отправке документа")
  end

  defp send_video(token, chat_id, video_url) when is_binary(video_url) and video_url != "" do
    url = "#{@base_url}#{token}/sendVideo"
    body = Jason.encode!(%{chat_id: chat_id, video: video_url})
    headers = [{"Content-Type", "application/json"}]
    options = [timeout: @request_timeout, recv_timeout: @request_timeout]

    case http_request(:post, url, body, headers, options, 1) do
      {:ok, %HTTPoison.Response{status_code: 200}} ->
        Logger.info("Video sent successfully to chat #{chat_id}")

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        Logger.error("Failed to send video to chat #{chat_id}: HTTP #{code}, body: #{body}")

      {:error, error} ->
        Logger.error("Failed to send video to chat #{chat_id}: #{inspect(error)}")
    end
  end

  defp send_video(token, chat_id, _video_url) do
    Logger.error("Invalid video URL for chat #{chat_id}")
    send_message(token, chat_id, "Ошибка при отправке видео")
  end

  defp send_sticker(token, chat_id, sticker_id) when is_binary(sticker_id) and sticker_id != "" do
    url = "#{@base_url}#{token}/sendSticker"
    body = Jason.encode!(%{chat_id: chat_id, sticker: sticker_id})
    headers = [{"Content-Type", "application/json"}]
    options = [timeout: @request_timeout, recv_timeout: @request_timeout]

    case http_request(:post, url, body, headers, options, 1) do
      {:ok, %HTTPoison.Response{status_code: 200}} ->
        Logger.info("Sticker sent successfully to chat #{chat_id}")

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        Logger.error("Failed to send sticker to chat #{chat_id}: HTTP #{code}, body: #{body}")

      {:error, error} ->
        Logger.error("Failed to send sticker to chat #{chat_id}: #{inspect(error)}")
    end
  end

  defp send_sticker(token, chat_id, _sticker_id) do
    Logger.error("Invalid sticker ID for chat #{chat_id}")
    send_message(token, chat_id, "Ошибка при отправке стикера")
  end

  defp send_animation(token, chat_id, animation_url)
       when is_binary(animation_url) and animation_url != "" do
    url = "#{@base_url}#{token}/sendAnimation"
    body = Jason.encode!(%{chat_id: chat_id, animation: animation_url})
    headers = [{"Content-Type", "application/json"}]
    options = [timeout: @request_timeout, recv_timeout: @request_timeout]

    case http_request(:post, url, body, headers, options, 1) do
      {:ok, %HTTPoison.Response{status_code: 200}} ->
        Logger.info("Animation sent successfully to chat #{chat_id}")

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        Logger.error("Failed to send animation to chat #{chat_id}: HTTP #{code}, body: #{body}")

      {:error, error} ->
        Logger.error("Failed to send animation to chat #{chat_id}: #{inspect(error)}")
    end
  end

  defp send_animation(token, chat_id, _animation_url) do
    Logger.error("Invalid animation URL for chat #{chat_id}")
    send_message(token, chat_id, "Ошибка при отправке анимации")
  end

  defp send_voice(token, chat_id, voice_url) when is_binary(voice_url) and voice_url != "" do
    url = "#{@base_url}#{token}/sendVoice"
    body = Jason.encode!(%{chat_id: chat_id, voice: voice_url})
    headers = [{"Content-Type", "application/json"}]
    options = [timeout: @request_timeout, recv_timeout: @request_timeout]

    case http_request(:post, url, body, headers, options, 1) do
      {:ok, %HTTPoison.Response{status_code: 200}} ->
        Logger.info("Voice message sent successfully to chat #{chat_id}")

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        Logger.error("Failed to send voice to chat #{chat_id}: HTTP #{code}, body: #{body}")

      {:error, error} ->
        Logger.error("Failed to send voice to chat #{chat_id}: #{inspect(error)}")
    end
  end

  defp send_voice(token, chat_id, _voice_url) do
    Logger.error("Invalid voice URL for chat #{chat_id}")
    send_message(token, chat_id, "Ошибка при отправке голосового сообщения")
  end

  defp send_keyboard(token, chat_id, keyboard_json) when is_binary(keyboard_json) do
    Logger.debug("Sending keyboard JSON: #{keyboard_json}")

    case Jason.decode(keyboard_json) do
      {:ok, %{"inline_keyboard" => keyboard} = json} ->
        url = "#{@base_url}#{token}/sendMessage"

        body =
          Jason.encode!(%{
            chat_id: chat_id,
            text: "Выберите опцию:",
            reply_markup: %{"inline_keyboard" => keyboard}
          })

        headers = [{"Content-Type", "application/json"}]
        options = [timeout: @request_timeout, recv_timeout: @request_timeout]

        case http_request(:post, url, body, headers, options, 1) do
          {:ok, %HTTPoison.Response{status_code: 200}} ->
            Logger.info("Inline keyboard sent successfully to chat #{chat_id}")

          {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
            Logger.error(
              "Failed to send inline keyboard to chat #{chat_id}: HTTP #{code}, body: #{body}"
            )

          {:error, error} ->
            Logger.error("Failed to send inline keyboard to chat #{chat_id}: #{inspect(error)}")
        end

      {:ok, %{"keyboard" => keyboard} = json} ->
        url = "#{@base_url}#{token}/sendMessage"

        display_keyboard =
          Enum.map(keyboard, fn row ->
            Enum.map(row, fn btn ->
              Map.take(btn, ["text", "request_contact", "request_location"])
            end)
          end)

        body =
          Jason.encode!(%{
            chat_id: chat_id,
            text: "Выберите опцию:",
            reply_markup: %{
              "keyboard" => display_keyboard,
              "resize_keyboard" => Map.get(json, "resize_keyboard", true),
              "one_time_keyboard" => Map.get(json, "one_time_keyboard", true)
            }
          })

        headers = [{"Content-Type", "application/json"}]
        options = [timeout: @request_timeout, recv_timeout: @request_timeout]

        case http_request(:post, url, body, headers, options, 1) do
          {:ok, %HTTPoison.Response{status_code: 200}} ->
            Logger.info("Reply keyboard sent successfully to chat #{chat_id}")

          {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
            Logger.error(
              "Failed to send reply keyboard to chat #{chat_id}: HTTP #{code}, body: #{body}"
            )

          {:error, error} ->
            Logger.error("Failed to send reply keyboard to chat #{chat_id}: #{inspect(error)}")
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

  defp answer_callback_query(token, callback_id) do
    url = "#{@base_url}#{token}/answerCallbackQuery"
    body = Jason.encode!(%{callback_query_id: callback_id})
    headers = [{"Content-Type", "application/json"}]
    options = [timeout: @request_timeout, recv_timeout: @request_timeout]

    case http_request(:post, url, body, headers, options, 1) do
      {:ok, %HTTPoison.Response{status_code: 200}} ->
        Logger.info("Callback query answered successfully")

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        Logger.error("Failed to answer callback query: HTTP #{code}, body: #{body}")

      {:error, error} ->
        Logger.error("Failed to answer callback query: #{inspect(error)}")
    end
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

    Logger.debug(
      "Broadcasting new_message for bot_id: #{bot_id}, message: #{inspect(message_data)}"
    )

    PubSub.broadcast(BotsPlatform.PubSub, "bot:#{bot_id}", {:new_message, message_data})
  end

  defp schedule_poll do
    Process.send_after(self(), :poll, @poll_interval)
  end

  defp http_request(:get, url, headers, options, attempt) do
    Logger.debug("HTTP GET attempt #{attempt} to #{url}")

    case HTTPoison.get(url, headers, options) do
      {:ok, response} ->
        {:ok, response}

      {:error, %HTTPoison.Error{reason: reason} = error} ->
        if attempt < @max_attempts do
          Logger.debug("Retrying after #{@retry_delay}ms due to #{inspect(reason)}")
          Process.sleep(@retry_delay)
          http_request(:get, url, headers, options, attempt + 1)
        else
          {:error, error}
        end
    end
  end

  defp http_request(:post, url, body, headers, options, attempt) do
    Logger.debug("HTTP POST attempt #{attempt} to #{url}")

    case HTTPoison.post(url, body, headers, options) do
      {:ok, response} ->
        {:ok, response}

      {:error, %HTTPoison.Error{reason: reason} = error} ->
        if attempt < @max_attempts do
          Logger.debug("Retrying after #{@retry_delay}ms due to #{inspect(reason)}")
          Process.sleep(@retry_delay)
          http_request(:post, url, body, headers, options, attempt + 1)
        else
          {:error, error}
        end
    end
  end
end
