defmodule BotsPlatformWeb.Schema.Types do
  use Absinthe.Schema.Notation
  import Absinthe.Resolution.Helpers, only: [dataloader: 1]

  @desc "ISO 8601 DateTime (например, 2025-05-13T15:17:00Z)"
  scalar :datetime do
    parse(fn input ->
      case input do
        %Absinthe.Blueprint.Input.String{value: value} ->
          case DateTime.from_iso8601(value) do
            {:ok, datetime, _offset} -> {:ok, datetime}
            {:error, _} -> :error
          end
        _ ->
          :error
      end
    end)

    serialize(fn datetime ->
      DateTime.to_iso8601(datetime)
    end)
  end

  enum :response_type do
    value(:TEXT, as: :text, description: "Текстовый ответ")
    value(:IMAGE, as: :image, description: "Изображение")
    value(:DOCUMENT, as: :document, description: "Документ")
    value(:VIDEO, as: :video, description: "Видео")
    value(:STICKER, as: :sticker, description: "Стикер")
    value(:ANIMATION, as: :animation, description: "Анимация")
    value(:VOICE, as: :voice, description: "Голосовое сообщение")
    value(:KEYBOARD, as: :keyboard, description: "Клавиатура (inline или reply)")
  end

  object :user do
    field(:id, non_null(:id))
    field(:name, non_null(:string))
    field(:email, non_null(:string))
    field(:is_admin, non_null(:boolean))
    field(:inserted_at, non_null(:datetime))
    field(:updated_at, non_null(:datetime))
    field(:bots, list_of(:bot), resolve: dataloader(BotsPlatform.Bots))
  end

  object :bot do
    field(:id, non_null(:id))
    field(:name, non_null(:string))
    field(:token, non_null(:string))
    field(:description, :string)
    field(:webhook_url, :string)
    field(:webhook_status, :string)
    field(:is_active, non_null(:boolean))
    field(:user_id, non_null(:id))
    field(:telegram_user_id, :string)
    field(:inserted_at, non_null(:datetime))
    field(:updated_at, non_null(:datetime))
    field(:user, non_null(:user), resolve: dataloader(BotsPlatform.Accounts))
    field(:commands, list_of(:command), resolve: dataloader(BotsPlatform.Bots))
    field(:messages, list_of(:message), resolve: dataloader(BotsPlatform.Messages))
    field(:chats, list_of(:chat), resolve: dataloader(BotsPlatform.Chats))
  end

  object :command do
    field(:id, non_null(:id))
    field(:name, non_null(:string))
    field(:description, :string)
    field(:trigger, non_null(:string))
    field(:response_type, non_null(:response_type))
    field(:response_content, non_null(:string))
    field(:is_active, non_null(:boolean))
    field(:bot_id, non_null(:id))
    field(:inserted_at, non_null(:datetime))
    field(:updated_at, non_null(:datetime))
    field(:bot, non_null(:bot), resolve: dataloader(BotsPlatform.Bots))
  end

  object :chat do
    field :id, :id
    field :chat_id, :string
    field :title, :string
    field :type, :string
    field :inserted_at, :datetime
    field :updated_at, :datetime
    field :messages, list_of(:message), resolve: dataloader(BotsPlatform.Messages)
  end

  object :message do
    field :id, :id
    field :chat_id, :string
    field :sender_id, :string
    field :sender_name, :string
    field :text, :string
    field :inserted_at, :datetime
  end

  object :delete_bot_result do
    field(:id, non_null(:id))
    field(:success, non_null(:boolean))
    field(:message, :string)
  end

  object :session do
    field(:token, non_null(:string))
    field(:user, non_null(:user))
  end

  object :subscription_result do
    field(:success, non_null(:boolean))
    field(:message, non_null(:string))
  end

  input_object :user_input do
    field(:name, non_null(:string))
    field(:email, non_null(:string))
    field(:password, non_null(:string))
    field(:is_admin, :boolean, default_value: false)
  end

  input_object :login_input do
    field(:email, non_null(:string))
    field(:password, non_null(:string))
  end

  input_object :bot_input do
    field(:name, non_null(:string))
    field(:token, non_null(:string))
    field(:description, :string)
    field(:webhook_url, :string)
    field(:is_active, :boolean, default_value: true)
    field(:telegram_user_id, :string)
  end

  input_object :command_input do
    field(:name, non_null(:string))
    field(:description, :string)
    field(:trigger, non_null(:string))
    field(:response_type, non_null(:response_type))
    field(:response_content, non_null(:string))
    field(:is_active, :boolean, default_value: true)
    field(:bot_id, non_null(:id))
  end

  input_object :message_input do
    field(:chat_id, non_null(:string))
    field(:text, non_null(:string))
    field(:bot_id, non_null(:id))
  end
end
