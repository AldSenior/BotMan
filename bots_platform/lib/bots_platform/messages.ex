defmodule BotsPlatform.Messages do
  import Ecto.Query
  alias BotsPlatform.Repo
  alias BotsPlatform.Messages.Message

  def data() do
    Dataloader.Ecto.new(Repo, query: &query/2)
  end

  def query(queryable, _params) do
    queryable
  end

  @doc """
  Получает список сообщений для бота.
  """
  def list_bot_messages(bot_id, limit \\ 100) do
    Message
    |> where(bot_id: ^bot_id)
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Создает новое сообщение.
  """
  def create_message(attrs \\ %{}) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Получает сообщение по ID.
  """
  def get_message(id), do: Repo.get(Message, id)

  @doc """
  Удаляет сообщение.
  """
  def delete_message(%Message{} = message) do
    Repo.delete(message)
  end

  @doc """
  Удаляет все сообщения бота.
  """
  def delete_bot_messages(bot_id) do
    Message
    |> where(bot_id: ^bot_id)
    |> Repo.delete_all()
  end
end
