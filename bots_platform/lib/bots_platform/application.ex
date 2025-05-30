defmodule BotsPlatform.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Репозиторий базы данных
      BotsPlatform.Repo,

      # Телеметрия для мониторинга
      BotsPlatformWeb.Telemetry,

      # Финч HTTP-клиент
      {Finch, name: BotsPlatform.Finch},

      # PubSub для внутренних событий
      {Phoenix.PubSub, name: BotsPlatform.PubSub},

      # HTTP сервер - теперь запускается ПЕРЕД Absinthe.Subscription
      BotsPlatformWeb.Endpoint,

      # Настройка Absinthe для подписок - теперь запускается ПОСЛЕ Endpoint
      {Absinthe.Subscription, BotsPlatformWeb.Endpoint},

      # Опрос Telegram API
      {BotsPlatform.Telegram.PollingHandler, []},

    ]

    opts = [strategy: :one_for_one, name: BotsPlatform.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    BotsPlatformWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
