defmodule BotsPlatformWeb.Schema.Types do
  use Absinthe.Schema.Notation
  import Absinthe.Resolution.Helpers, only: [dataloader: 1]

  # Enum типы
  @desc "Тип ответа команды"
  enum :response_type do
    value(:TEXT, as: :text)
    value(:IMAGE, as: :image)
    value(:DOCUMENT, as: :document)
    value(:KEYBOARD, as: :keyboard)
  end

  @desc "Пользователь"
  object :user do
    field :id, non_null(:id)
    field :name, non_null(:string)
    field :email, non_null(:string)
    field :is_admin, non_null(:boolean)
    field :inserted_at, non_null(:string)
    field :updated_at, non_null(:string)

    field :bots, list_of(:bot), resolve: dataloader(BotsPlatform.Bots)
  end

  @desc "Бот"
  object :bot do
    field :id, non_null(:id)
    field :name, non_null(:string)
    field :token, non_null(:string)
    field :description, :string
    field :webhook_url, :string
    field :is_active, non_null(:boolean)
    field :user_id, non_null(:id)
    field :inserted_at, non_null(:string)
    field :updated_at, non_null(:string)

    field :user, non_null(:user), resolve: dataloader(BotsPlatform.Accounts)
    field :commands, list_of(:command), resolve: dataloader(BotsPlatform.Bots)
    field :messages, list_of(:message), resolve: dataloader(BotsPlatform.Messages)
  end

  @desc "Команда бота"
  object :command do
    field :id, non_null(:id)
    field :name, non_null(:string)
    field :description, :string
    field :trigger, non_null(:string)
    field :response_type, non_null(:response_type)
    field :response_content, non_null(:string)
    field :is_active, non_null(:boolean)
    field :bot_id, non_null(:id)
    field :inserted_at, non_null(:string)
    field :updated_at, non_null(:string)

    field :bot, non_null(:bot), resolve: dataloader(BotsPlatform.Bots)
  end

  @desc "Сообщение"
  object :message do
    field :id, non_null(:id)
    field :chat_id, non_null(:string)
    field :sender_id, non_null(:string)
    field :sender_name, non_null(:string)
    field :text, non_null(:string)
    field :bot_id, non_null(:id)
    field :inserted_at, non_null(:string)
    field :updated_at, non_null(:string)

    field :bot, non_null(:bot), resolve: dataloader(BotsPlatform.Bots)
  end

  @desc "Результат авторизации"
  object :session do
    field :token, non_null(:string)
    field :user, non_null(:user)
  end

  @desc "Результат операции подписки"
  object :subscription_result do
    field :success, non_null(:boolean)
    field :message, non_null(:string)
  end

  # Входные объекты

  @desc "Данные для создания пользователя"
  input_object :user_input do
    field :name, non_null(:string)
    field :email, non_null(:string)
    field :password, non_null(:string)
    field :is_admin, :boolean, default_value: false
  end

  @desc "Данные для входа пользователя"
  input_object :login_input do
    field :email, non_null(:string)
    field :password, non_null(:string)
  end

  @desc "Данные для создания или обновления бота"
  input_object :bot_input do
    field :name, non_null(:string)
    field :token, non_null(:string)
    field :description, :string
    field :webhook_url, :string
    field :is_active, :boolean, default_value: true
  end

  @desc "Данные для создания или обновления команды"
  input_object :command_input do
    field :name, non_null(:string)
    field :description, :string
    field :trigger, non_null(:string)
    field :response_type, non_null(:response_type)
    field :response_content, non_null(:string)
    field :is_active, :boolean, default_value: true
    field :bot_id, non_null(:id)
  end
end
