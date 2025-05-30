# lib/bots_platform_web/controllers/chat_controller.ex
defmodule BotsPlatformWeb.ChatController do
  use BotsPlatformWeb, :controller

  alias BotsPlatform.{Chats, Messages}
  alias BotsPlatform.Chats.Chat

  def index(conn, %{"bot_id" => bot_id}) do
    chats = Chats.list_chats_by_bot(bot_id)
    render(conn, "index.json", chats: chats)
  end

  def show(conn, %{"bot_id" => bot_id, "chat_id" => chat_id}) do
    case Chats.get_chat_by_chat_id(chat_id, bot_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Chat not found"})
      chat ->
        render(conn, "show.json", chat: chat)
    end
  end

  def messages(conn, %{"bot_id" => bot_id, "chat_id" => chat_id}) do
    messages = Messages.list_messages_by_chat(chat_id, bot_id)
    render(conn, "messages.json", messages: messages)
  end
end
