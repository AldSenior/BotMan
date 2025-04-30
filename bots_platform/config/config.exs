import Config

config :bots_platform,
  ecto_repos: [BotsPlatform.Repo],
  generators: [binary_id: true]

# Guardian конфигурация
config :bots_platform, BotsPlatform.Auth.Guardian,
  issuer: "bots_platform",
  # В продакшене использовать env var
  secret_key: "секретный_ключ_для_разработки"

config :swoosh, :api_client, Swoosh.ApiClient.Hackney

# Конфигурация для EndPoint
config :bots_platform, BotsPlatformWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [json: BotsPlatformWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: BotsPlatform.PubSub,
  live_view: [signing_salt: "секретный_ключ"]

# Absinthe конфигурация
config :absinthe, schema: BotsPlatformWeb.Schema

config :ex_gram,
  json_library: Jason

# config :telegex,
#   # Оставляем nil, так как используем токены из базы данных
#   token: nil,
#   adapter: Telegex.Adapter.Tesla

config :tesla, adapter: Tesla.Adapter.Hackney

# Настройте Absinthe.Phoenix с использованием PubSub
config :absinthe, Absinthe.Subscription,
  pubsub: [
    name: BotsPlatform.PubSub
  ]

# Конфигурация логирования
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Конфигурация JSON сериализации
config :phoenix, :json_library, Jason

# Импорт конфигурации для текущего окружения
import_config "#{config_env()}.exs"
