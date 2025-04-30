defmodule BotsPlatform.Repo do
  use Ecto.Repo,
    otp_app: :bots_platform,
    adapter: Ecto.Adapters.Postgres
end
