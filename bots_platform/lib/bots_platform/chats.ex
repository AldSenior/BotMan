defmodule BotsPlatform.Chats do
  import Ecto.Query, warn: false
  alias BotsPlatform.Repo
  alias BotsPlatform.Chats.Chat

  def data do
    Dataloader.Ecto.new(Repo, query: &query/2)
  end

  def query(queryable, _params) do
    queryable
  end

  def list_bot_chats(bot_id) do
    Chat
    |> where([c], c.bot_id == ^bot_id)
    |> Repo.all()
    |> Repo.preload(:messages)
  end

  def get_chat_by_chat_id(chat_id, bot_id) do
    case Repo.get_by(Chat, chat_id: chat_id, bot_id: bot_id) do
      nil -> {:error, "Chat not found"}
      chat -> {:ok, Repo.preload(chat, :messages)}
    end
  end

  def get_chat(id) do
    case Repo.get(Chat, id) do
      nil -> {:error, "Chat not found"}
      chat -> {:ok, Repo.preload(chat, :messages)}
    end
  end

  def create_chat(attrs \\ %{}) do
    %Chat{}
    |> Chat.changeset(attrs)
    |> Repo.insert()
  end

  def update_chat(%Chat{} = chat, attrs) do
    chat
    |> Chat.changeset(attrs)
    |> Repo.update()
  end

  def delete_chat(%Chat{} = chat) do
    Repo.delete(chat)
  end
end
