defmodule BotsPlatform.Bots.Command do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "commands" do
    field :name, :string
    field :description, :string
    field :trigger, :string

    field :response_type, Ecto.Enum,
      values: [
        :text,
        :image,
        :document,
        :video,
        :sticker,
        :animation,
        :voice,
        :keyboard
      ]

    field :response_content, :string
    field :is_active, :boolean, default: true

    belongs_to :bot, BotsPlatform.Bots.Bot

    timestamps(type: :utc_datetime)
  end

  def changeset(command, attrs) do
    attrs =
      if is_binary(attrs["response_type"]) || is_binary(attrs[:response_type]) do
        Map.update!(attrs, :response_type, &String.downcase/1)
      else
        attrs
      end

    command
    |> cast(attrs, [
      :name,
      :description,
      :trigger,
      :response_type,
      :response_content,
      :is_active,
      :bot_id
    ])
    |> validate_required([:name, :trigger, :response_type, :response_content, :bot_id])
    |> foreign_key_constraint(:bot_id)
    |> validate_response_content()
  end

  defp validate_response_content(changeset) do
    response_type = get_field(changeset, :response_type)
    response_content = get_field(changeset, :response_content)

    case response_type do
      :keyboard ->
        case Jason.decode(response_content) do
          {:ok, json} ->
            case valid_keyboard?(json) do
              {:ok, _} -> changeset
              {:error, reason} -> add_error(changeset, :response_content, reason)
            end

          {:error, _} ->
            add_error(changeset, :response_content, "Невалидный JSON")
        end

      :image ->
        validate_url_or_file_id(
          changeset,
          response_content,
          "Невалидный URL или file_id изображения"
        )

      :document ->
        validate_url_or_file_id(
          changeset,
          response_content,
          "Невалидный URL или file_id документа"
        )

      :video ->
        validate_url_or_file_id(changeset, response_content, "Невалидный URL или file_id видео")

      :sticker ->
        validate_url_or_file_id(changeset, response_content, "Невалидный URL или file_id стикера")

      :animation ->
        validate_url_or_file_id(
          changeset,
          response_content,
          "Невалидный URL или file_id анимации"
        )

      :voice ->
        validate_url_or_file_id(
          changeset,
          response_content,
          "Невалидный URL или file_id голосового сообщения"
        )

      :text ->
        if response_content != "" do
          changeset
        else
          add_error(changeset, :response_content, "Текстовое содержимое не может быть пустым")
        end

      _ ->
        add_error(changeset, :response_type, "Недопустимый тип ответа")
    end
  end

  defp valid_keyboard?(json) do
    cond do
      !is_map(json) ->
        {:error, "JSON должен быть объектом"}

      Map.has_key?(json, "inline_keyboard") ->
        validate_inline_keyboard(json)

      Map.has_key?(json, "keyboard") ->
        validate_reply_keyboard(json)

      true ->
        {:error, "Отсутствует inline_keyboard или keyboard"}
    end
  end

  defp validate_inline_keyboard(json) do
    with true <- is_list(json["inline_keyboard"]),
         true <- Map.has_key?(json, "actions"),
         true <- is_map(json["actions"]),
         true <-
           Enum.all?(json["inline_keyboard"], fn row ->
             is_list(row) &&
               Enum.all?(row, fn btn ->
                 is_map(btn) &&
                   Map.has_key?(btn, "text") && is_binary(btn["text"]) && btn["text"] != "" &&
                   Map.has_key?(btn, "callback_data") && is_binary(btn["callback_data"]) &&
                   btn["callback_data"] != ""
               end)
           end),
         true <-
           Enum.all?(Map.values(json["actions"]), fn action ->
             is_map(action) &&
               Map.has_key?(action, "type") &&
               action["type"] in [
                 "send_message",
                 "send_photo",
                 "send_document",
                 "send_video",
                 "send_sticker",
                 "send_animation",
                 "send_voice"
               ] &&
               Map.has_key?(action, "content") &&
               is_binary(action["content"]) &&
               action["content"] != ""
           end) do
      {:ok, :inline_keyboard}
    else
      _ -> {:error, "Некорректный формат inline_keyboard или действий"}
    end
  end

  defp validate_reply_keyboard(json) do
    with true <- is_list(json["keyboard"]),
         true <- Map.has_key?(json, "actions"),
         true <- is_map(json["actions"]),
         true <-
           Enum.all?(json["keyboard"], fn row ->
             is_list(row) &&
               Enum.all?(row, fn btn ->
                 is_map(btn) &&
                   ((Map.has_key?(btn, "text") && is_binary(btn["text"]) && btn["text"] != "" &&
                       Map.has_key?(btn, "send_text") && is_binary(btn["send_text"]) &&
                       btn["send_text"] != "") ||
                      Map.get(btn, "request_contact", false) == true ||
                      Map.get(btn, "request_location", false) == true)
               end)
           end),
         true <-
           Enum.all?(Map.values(json["actions"]), fn action ->
             is_map(action) &&
               Map.has_key?(action, "type") &&
               action["type"] in [
                 "send_message",
                 "send_photo",
                 "send_document",
                 "send_video",
                 "send_sticker",
                 "send_animation",
                 "send_voice"
               ] &&
               Map.has_key?(action, "content") &&
               is_binary(action["content"]) &&
               action["content"] != ""
           end) do
      {:ok, :reply_keyboard}
    else
      _ ->
        {:error,
         "Некорректный формат reply_keyboard: текстовая кнопка должна иметь text, send_text и действие, другие — текст опционально"}
    end
  end

  defp validate_url_or_file_id(changeset, content, error_message) do
    # Проверяем, является ли content валидным URL или file_id
    if content =~ ~r/^https?:\/\/.+/ or content =~ ~r/^[A-Za-z0-9_-]+$/ do
      changeset
    else
      add_error(changeset, :response_content, error_message)
    end
  end
end
