defmodule BotsPlatformWeb.Schema do
  use Absinthe.Schema

  import_types(BotsPlatformWeb.Schema.Types)
  alias BotsPlatformWeb.Resolvers

  def context(ctx) do
    loader =
      Dataloader.new()
      |> Dataloader.add_source(BotsPlatform.Accounts, BotsPlatform.Accounts.data())
      |> Dataloader.add_source(BotsPlatform.Bots, BotsPlatform.Bots.data())
      |> Dataloader.add_source(BotsPlatform.Messages, BotsPlatform.Messages.data())

    Map.put(ctx, :loader, loader)
  end

  def plugins do
    [Absinthe.Middleware.Dataloader] ++ Absinthe.Plugin.defaults()
  end

  # Запросы
  query do
    @desc "Получить информацию о текущем пользователе"
    field :me, :user do
      arg(:token, non_null(:string))
      resolve(&Resolvers.Accounts.get_user/3)
    end

    @desc "Получить список ботов"
    field :bots, list_of(:bot) do
      arg(:token, non_null(:string))
      resolve(&Resolvers.Bots.list_bots/3)
    end

    @desc "Получить бота по ID"
    field :bot, :bot do
      arg(:id, non_null(:id))
      arg(:token, non_null(:string))
      resolve(&Resolvers.Bots.get_bot/3)
    end

    @desc "Получить список команд бота"
    field :commands, list_of(:command) do
      arg(:bot_id, non_null(:id))
      arg(:token, non_null(:string))
      resolve(&Resolvers.Bots.list_commands/3)
    end

    @desc "Получить список сообщений бота"
    field :messages, list_of(:message) do
      arg(:bot_id, non_null(:id))
      arg(:token, non_null(:string))
      resolve(&Resolvers.Messages.list_messages/3)
    end

    @desc "Получить список ботов, на которые подписан пользователь"
    field :subscribed_bots, list_of(:bot) do
      arg(:token, non_null(:string))
      resolve(&Resolvers.Subscriptions.list_subscribed_bots/3)
    end

    @desc "Проверить подписку на бота"
    field :is_subscribed, :boolean do
      arg(:bot_id, non_null(:id))
      arg(:token, non_null(:string))
      resolve(&Resolvers.Subscriptions.is_subscribed/3)
    end
  end

  # Мутации
  mutation do
    @desc "Регистрация нового пользователя"
    field :register, :session do
      arg(:input, non_null(:user_input))
      resolve(&Resolvers.Accounts.register_user/3)
    end

    @desc "Вход пользователя"
    field :login, :session do
      arg(:input, non_null(:login_input))
      resolve(&Resolvers.Accounts.login/3)
    end

    @desc "Создание нового бота"
    field :create_bot, :bot do
      arg(:input, non_null(:bot_input))
      arg(:token, non_null(:string))
      resolve(&Resolvers.Bots.create_bot/3)
    end

    @desc "Обновление бота"
    field :update_bot, :bot do
      arg(:id, non_null(:id))
      arg(:input, non_null(:bot_input))
      arg(:token, non_null(:string))
      resolve(&Resolvers.Bots.update_bot/3)
    end

    @desc "Удаление бота"
    field :delete_bot, :bot do
      arg(:id, non_null(:id))
      arg(:token, non_null(:string))
      resolve(&Resolvers.Bots.delete_bot/3)
    end

    @desc "Создание команды бота"
    field :create_command, :command do
      arg(:input, non_null(:command_input))
      arg(:token, non_null(:string))
      resolve(&Resolvers.Bots.create_command/3)
    end

    @desc "Обновление команды бота"
    field :update_command, :command do
      arg(:id, non_null(:id))
      arg(:input, non_null(:command_input))
      arg(:token, non_null(:string))
      resolve(&Resolvers.Bots.update_command/3)
    end

    @desc "Удаление команды бота"
    field :delete_command, :command do
      arg(:id, non_null(:id))
      arg(:token, non_null(:string))
      resolve(&Resolvers.Bots.delete_command/3)
    end

    @desc "Подписка на бота"
    field :subscribe_to_bot, :subscription_result do
      arg(:bot_id, non_null(:id))
      arg(:token, non_null(:string))
      resolve(&Resolvers.Subscriptions.subscribe_to_bot/3)
    end

    @desc "Отписка от бота"
    field :unsubscribe_from_bot, :subscription_result do
      arg(:bot_id, non_null(:id))
      arg(:token, non_null(:string))
      resolve(&Resolvers.Subscriptions.unsubscribe_from_bot/3)
    end
  end

  # Подписки
  subscription do
    @desc "Подписка на новые сообщения от бота"
    field :new_message, :message do
      arg(:bot_id, non_null(:id))
      arg(:token, non_null(:string))

      config(fn args, _ ->
        case authenticate_token(args.token) do
          {:ok, user} ->
            bot = BotsPlatform.Bots.get_bot(args.bot_id)

            cond do
              is_nil(bot) ->
                {:error, "Бот не найден"}

              user.is_admin || bot.user_id == user.id ||
                  BotsPlatform.Subscriptions.is_subscribed?(user.id, bot.id) ->
                {:ok, topic: "bot:#{args.bot_id}"}

              true ->
                {:error, "Нет доступа к этому боту"}
            end

          {:error, reason} ->
            {:error, reason}
        end
      end)

      trigger([:new_message],
        topic: fn message ->
          "bot:#{message.bot_id}"
        end
      )

      resolve(fn payload, _, _ ->
        {:ok, payload}
      end)
    end
  end

  # Вспомогательные функции
  defp authenticate_token("Bearer " <> token) do
    case BotsPlatform.Auth.Guardian.decode_and_verify(token) do
      {:ok, claims} -> BotsPlatform.Auth.Guardian.resource_from_claims(claims)
      error -> error
    end
  end

  defp authenticate_token(token) do
    authenticate_token("Bearer #{token}")
  end
end
