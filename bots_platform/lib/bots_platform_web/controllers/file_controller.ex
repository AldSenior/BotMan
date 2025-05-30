defmodule BotsPlatformWeb.FileController do
  use BotsPlatformWeb, :controller
  alias BotsPlatform.Bots
  require Logger

  # 10MB
  @max_file_size 10 * 1024 * 1024
  @allowed_types %{
    "sticker" => ["image/webp"],
    "image" => ["image/jpeg", "image/png", "image/gif"],
    "video" => ["video/mp4", "video/mpeg"],
    "animation" => ["image/gif", "video/mp4"],
    "document" => ["application/pdf", "text/plain", "application/msword"],
    "voice" => ["audio/ogg", "audio/mpeg"]
  }

  def upload(conn, %{"file" => %Plug.Upload{} = upload, "response_type" => response_type}) do
    Logger.debug("Upload attempt: response_type=#{response_type}, filename=#{upload.filename}")

    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, claims} <- BotsPlatform.Auth.Guardian.decode_and_verify(token),
         {:ok, user} <- BotsPlatform.Auth.Guardian.resource_from_claims(claims) do
      # Валидация типа ответа
      unless Map.has_key?(@allowed_types, response_type) do
        Logger.error("Invalid response_type: #{response_type}")
        return_error(conn, :bad_request, "Invalid response_type")
      end

      # Валидация типа файла
      unless upload.content_type in @allowed_types[response_type] do
        Logger.error(
          "Invalid file type: #{upload.content_type} for response_type: #{response_type}"
        )

        return_error(conn, :bad_request, "Invalid file type")
      end

      # Валидация размера файла
      case File.stat(upload.path) do
        {:ok, %{size: file_size}} ->
          if file_size > @max_file_size do
            Logger.error("File too large: #{file_size} bytes")
            return_error(conn, :bad_request, "File size exceeds 10MB")
          end

        {:error, reason} ->
          Logger.error("Failed to get file size: #{inspect(reason)}")
          return_error(conn, :bad_request, "Invalid file")
      end

      # Получаем первого активного бота пользователя
      bot = Bots.list_bots_for_user(user.id) |> List.first()

      unless bot do
        Logger.error("No active bot found for user: #{user.id}")
        return_error(conn, :not_found, "No active bot found")
      end

      unless bot.token do
        Logger.error("Bot token missing for bot: #{bot.id}")
        return_error(conn, :internal_server_error, "Bot token missing")
      end

      # Проверка admin_chat_id
      admin_chat_id = Application.get_env(:bots_platform, :admin_chat_id)

      unless admin_chat_id do
        Logger.error("Admin chat_id not configured")
        return_error(conn, :internal_server_error, "Admin chat_id not configured")
      end

      try do
        case response_type do
          "sticker" ->
            case upload_sticker_to_telegram(bot.token, upload, admin_chat_id) do
              {:ok, file_id} ->
                Logger.debug("Sticker uploaded successfully: file_id=#{file_id}")
                json(conn, %{file_id: file_id})

              {:error, reason} ->
                Logger.error("Failed to upload sticker: #{reason}")
                return_error(conn, :bad_request, "Failed to upload sticker: #{reason}")
            end

          type when type in ["image", "video", "animation", "document", "voice"] ->
            case save_file_locally(upload) do
              {:ok, url} ->
                Logger.debug("File saved locally: url=#{url}")
                json(conn, %{url: url})

              {:error, reason} ->
                Logger.error("Failed to save file locally: #{reason}")
                return_error(conn, :bad_request, "Failed to save file: #{reason}")
            end
        end
      rescue
        e ->
          Logger.error("Unexpected error during file upload: #{inspect(e)}")
          return_error(conn, :internal_server_error, "Failed to process file")
      end
    else
      _ ->
        Logger.error("Unauthorized access attempt")
        return_error(conn, :unauthorized, "Unauthorized")
    end
  end

  def upload(conn, _params) do
    Logger.error("Invalid upload parameters")
    return_error(conn, :bad_request, "Missing file or response_type")
  end

  defp upload_sticker_to_telegram(token, upload, chat_id) do
    url = "https://api.telegram.org/bot#{token}/sendSticker"

    form = [
      {:chat_id, chat_id},
      {:sticker, upload}
    ]

    Logger.debug("Sending sticker to Telegram: chat_id=#{chat_id}")

    case HTTPoison.post(url, {:multipart, form}, [], timeout: 10_000, recv_timeout: 10_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"ok" => true, "result" => %{"sticker" => %{"file_id" => file_id}}}} ->
            {:ok, file_id}

          {:ok, %{"ok" => false, "description" => desc}} ->
            {:error, "Telegram API error: #{desc}"}

          {:ok, unexpected} ->
            {:error, "Unexpected Telegram response: #{inspect(unexpected)}"}

          {:error, error} ->
            {:error, "Failed to decode Telegram response: #{inspect(error)}"}
        end

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        {:error, "Telegram API error: HTTP #{code}, body: #{body}"}

      {:error, error} ->
        {:error, "HTTP request failed: #{inspect(error)}"}
    end
  end

  defp save_file_locally(%Plug.Upload{filename: filename, path: path}) do
    try do
      ext = Path.extname(filename)
      unique_filename = "#{UUID.uuid4()}#{ext}"
      dest_path = Path.join(["priv", "static", "uploads", unique_filename])

      Logger.debug("Saving file locally: dest_path=#{dest_path}")

      File.mkdir_p!(Path.dirname(dest_path))
      File.cp!(path, dest_path)

      {:ok, "/uploads/#{unique_filename}"}
    rescue
      e ->
        Logger.error("Failed to save file locally: #{inspect(e)}")
        {:error, "Failed to save file: #{inspect(e)}"}
    end
  end

  defp return_error(conn, status, message) do
    Logger.debug("Returning error: status=#{status}, message=#{message}")

    conn
    |> put_status(status)
    |> json(%{error: message})
  end
end
