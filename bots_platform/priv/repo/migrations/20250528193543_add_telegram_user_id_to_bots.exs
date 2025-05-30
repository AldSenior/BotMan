defmodule BotsPlatform.Repo.Migrations.AddTelegramUserIdToBots do
  use Ecto.Migration

  def change do
    alter table(:bots) do
      add :telegram_user_id, :string
    end
  end
end
