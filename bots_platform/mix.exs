defmodule BotsPlatform.MixProject do
  use Mix.Project

  def project do
    [
      app: :bots_platform,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {BotsPlatform.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.7.6"},
      {:dataloader, "~> 1.0"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_live_dashboard, "~> 0.8.0"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:jason, "~> 1.4"},
      {:plug_cowboy, "~> 2.5"},
      # Telegram API клиент
      {:ex_gram, "~> 0.55.0"},
      {:finch, "~> 0.16"},
      {:httpoison, "~> 2.0"},
      # GraphQL сервер
      {:absinthe, "~> 1.7"},
      # GraphQL через HTTP
      {:uuid, "~> 1.1"},
      {:absinthe_plug, "~> 1.5"},
      {:swoosh, "~> 1.5"},
      # GraphQL через WebSocket
      {:absinthe_phoenix, "~> 2.0"},
      # CORS поддержка
      {:cors_plug, "~> 3.0"},
      # Аутентификация и авторизация
      {:guardian, "~> 2.3"},
      # Хеширование паролей
      #
      {:tesla, "~> 1.4"},
      {:bcrypt_elixir, "~> 3.0"},
      {:hackney, "~> 1.9"},
      # Линтер для Elixir
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      # Документация
      {:ex_doc, "~> 0.29", only: :dev, runtime: false}
    ]
  end

  # defp aliases do
  #   [
  #     setup: ["deps.get", "ecto.setup"],
  #     "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
  #     "ecto.reset": ["ecto.drop", "ecto.setup"],
  #     test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
  #   ]
  # end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind bots_platform", "esbuild bots_platform"],
      "assets.deploy": [
        "tailwind bots_platform --minify",
        "esbuild bots_platform --minify",
        "phx.digest"
      ]
    ]
  end
end
