import Config

# Конфигурация базы данных
config :bots_platform, BotsPlatform.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "bots_platform_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Конфигурация для EndPoint
config :bots_platform, BotsPlatformWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "секретный_ключ_для_разработки",
  watchers: []

# Настройка консоли
config :bots_platform, dev_routes: true

# Конфигурация логирования
config :logger, :console, format: "[$level] $message\n"

# Устанавливаем уровень логирования для просмотра SQL запросов
config :logger, level: :info

# Устанавливаем размер стека ошибок
config :phoenix, :stacktrace_depth, 20

# Инициализация plugs
config :phoenix, :plug_init_mode, :runtime
