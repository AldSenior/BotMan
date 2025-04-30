defmodule BotsPlatform.Bots do
  import Ecto.Query
  alias BotsPlatform.Repo
  alias BotsPlatform.Bots.{Bot, Command}
  require Logger

  def data() do
    Dataloader.Ecto.new(Repo, query: &query/2)
  end

  def query(queryable, _params) do
    queryable
  end

  @doc """
  Создает нового бота.
  """
  def create_bot(attrs \\ %{}) do
    %Bot{}
    |> Bot.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Получает бота по ID.
  """
  def get_bot(id), do: Repo.get(Bot, id)

  @doc """
  Получает список всех ботов.
  """
  def list_bots do
    Logger.info("Fetching all bots")

    Bot
    |> Repo.all()
    |> Repo.preload([:user, :commands])
  end

  def list_user_bots(user_id) do
    Logger.info("Fetching bots for user #{user_id}")

    Bot
    |> where([b], b.user_id == ^user_id)
    |> Repo.all()
    |> Repo.preload([:user, :commands])
  end

  @doc """
  Обновляет бота.
  """
  def update_bot(%Bot{} = bot, attrs) do
    bot
    |> Bot.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Удаляет бота.
  """
  def delete_bot(%Bot{} = bot) do
    Repo.delete(bot)
  end

  @doc """
  Получает список команд бота.
  """
  def list_bot_commands(bot_id) do
    Command
    |> where(bot_id: ^bot_id)
    |> where(is_active: true)
    |> Repo.all()
  end

  @doc """
  Создает новую команду для бота.
  """
  def create_command(attrs \\ %{}) do
    %Command{}
    |> Command.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Обновляет команду.
  """
  def update_command(%Command{} = command, attrs) do
    command
    |> Command.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Удаляет команду.
  """
  def delete_command(%Command{} = command) do
    Repo.delete(command)
  end

  @doc """
  Получает команду по ID.
  """
  def get_command(id), do: Repo.get(Command, id)
end
