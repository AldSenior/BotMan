defmodule BotsPlatform.Repo.Migrations.FixChatsIdType do
  use Ecto.Migration

  def up do
    # Добавить временное поле для UUID
    alter table(:chats) do
      add :new_id, :uuid, default: fragment("gen_random_uuid()")
    end

    # Заполнить new_id уникальными UUID для существующих записей
    execute "UPDATE chats SET new_id = gen_random_uuid();"

    # Удалить старый первичный ключ
    execute "ALTER TABLE chats DROP CONSTRAINT chats_pkey;"

    # Удалить старое поле id
    alter table(:chats) do
      remove :id
    end

    # Переименовать new_id в id и установить как первичный ключ
    execute "ALTER TABLE chats RENAME COLUMN new_id TO id;"
    execute "ALTER TABLE chats ADD PRIMARY KEY (id);"
  end

  def down do
    # Обратная миграция: вернуть bigserial
    alter table(:chats) do
      add :new_id, :bigserial
    end

    execute "ALTER TABLE chats DROP CONSTRAINT chats_pkey;"
    alter table(:chats) do
      remove :id
    end

    execute "ALTER TABLE chats RENAME COLUMN new_id TO id;"
    execute "ALTER TABLE chats ADD PRIMARY KEY (id);"
  end
end
